defmodule K8s.Client.MintHTTPProvider do
  @moduledoc """
  HTTPoison and Jason based `K8s.Client.Provider`
  """
  @behaviour K8s.Client.Provider
  require Logger
  require Mint.HTTP

  defstruct [:conn, :request_ref]

  @impl true
  def request(method, url, body, headers, http_opts) do
    stream(method, url, body, headers, http_opts)
    |> Enum.reduce_while(%{chunks: [], status: nil, headers: []}, fn
      {:data, responses}, acc -> {:cont, Map.update!(acc, :chunks, &[responses | &1])}
      {:status, code}, acc -> {:cont, Map.put(acc, :status, code)}
      {:headers, headers}, acc -> {:cont, Map.update!(acc, :headers, &(&1 ++ headers))}
      {:error, error}, _acc -> {:halt, {:error, error}}
      _other, acc -> {:cont, acc}
    end)
    |> process_response()
  end

  @impl true
  def stream(method, url, body, headers, http_opts) do
    method = String.upcase("#{method}")
    server = URI.parse(url)
    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)

    query =
      case Keyword.get(http_opts, :params, []) do
        [] -> ""
        params -> "?#{URI.encode_query(params)}"
      end

    Stream.resource(
      fn ->
        {:ok, conn} =
          Mint.HTTP.connect(String.to_atom(server.scheme), server.host, server.port,
            transport_opts: Keyword.fetch!(http_opts, :ssl)
          )

        {:ok, conn, request_ref} =
          Mint.HTTP.request(conn, method, "#{server.path}#{query}", headers, body)

        struct!(__MODULE__, conn: conn, request_ref: request_ref)
      end,
      &next_fun/1,
      fn _ -> :ok end
    )
  end

  defp next_fun(:halt), do: {:halt, nil}

  defp next_fun(state) do
    receive do
      message when Mint.HTTP.is_connection_message(state.conn, message) ->
        {:ok, conn, responses} = Mint.HTTP.stream(state.conn, message)

        # todo: is :done always last element? => reverse |> hd
        if Enum.member?(responses, {:done, state.request_ref}) do
          {Enum.map(responses, &map_responses/1), :halt}
        else
          {Enum.map(responses, &map_responses/1), struct!(state, conn: conn)}
        end

      _other ->
        # todo log
        {[], state}
    end
  end

  defp map_responses({type, _ref}), do: type
  defp map_responses({type, _ref, data}), do: {type, data}

  defp process_response({:error, error}), do: K8s.Client.HTTPError.new(message: error)

  defp process_response(%{status: status} = response) when status in 400..599 do
    %{chunks: chunks, headers: headers, status: status_code} = response

    case get_content_type(headers) do
      "application/json" = content_type ->
        chunks
        |> IO.iodata_to_binary()
        |> decode(content_type)
        |> K8s.Client.APIError.from_kubernetes_error()

      _other ->
        {:error, K8s.Client.HTTPError.new(message: "HTTP Error #{status_code}")}
    end
  end

  defp process_response(response) do
    content_type = get_content_type(response.headers)
    body = response.chunks |> IO.iodata_to_binary() |> decode(content_type)

    {:ok, body}
  end

  @spec get_content_type(keyword()) :: binary | nil
  defp get_content_type(headers) do
    case List.keyfind(headers, "content-type", 0) do
      {_key, content_type} -> content_type
      _ -> nil
    end
  end

  @spec decode(binary, binary) :: map | list | nil
  defp decode(body, "text/plain"), do: body

  defp decode(body, "application/json") do
    case Jason.decode(body) do
      {:ok, data} -> data
      {:error, _} -> nil
    end
  end
end
