defmodule K8s.Client.MintHTTPProvider do
  @moduledoc """
  HTTPoison and Jason based `K8s.Client.Provider`
  """
  @behaviour K8s.Client.Provider
  require Logger
  require Mint.HTTP

  alias K8s.Client.HTTPError

  defstruct [:conn, :request_ref]

  @impl true
  def request(method, url, body, headers, http_opts) do
    with {:ok, stream} <- stream(method, url, body, headers, http_opts) do
      Enum.reduce_while(stream, %{chunks: [], status: nil, headers: []}, fn
        {:data, responses}, acc -> {:cont, Map.update!(acc, :chunks, &[responses | &1])}
        {:status, code}, acc -> {:cont, Map.put(acc, :status, code)}
        {:headers, headers}, acc -> {:cont, Map.update!(acc, :headers, &(&1 ++ headers))}
        {:error, error}, _acc -> {:halt, {:error, error}}
        _other, acc -> {:cont, acc}
      end)
      |> process_response()
    end
  end

  @impl true
  def stream(method, url, body, headers, http_opts) do
    server = URI.parse(url)

    with {:ok, conn} <- connect(server, http_opts) do
      stream = create_stream(conn, method, server, body, headers, http_opts)
      {:ok, stream}
    end
  end

  defp connect(server, http_opts) do
    transport_opts = Keyword.fetch!(http_opts, :ssl)

    case Mint.HTTP.connect(
           String.to_atom(server.scheme),
           server.host,
           server.port,
           transport_opts: transport_opts
         ) do
      {:error, error}
      when is_exception(error, Mint.HTTPError) or
             is_exception(error, Mint.TransportError) ->
        {:error, HTTPError.new(message: error.reason, adapter_specific_error: error)}

      {:ok, conn} ->
        {:ok, conn}
    end
  end

  defp create_stream(conn, method, server, body, headers, http_opts) do
    method = String.upcase("#{method}")
    query = http_opts |> Keyword.get(:params, []) |> URI.encode_query()
    path = String.trim(server.path <> "?" <> query, "?")
    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)

    Stream.resource(
      fn -> start_request(conn, method, path, body, headers) end,
      &next_fun/1,
      fn state -> Mint.HTTP.close(state.conn) end
    )
  end

  defp start_request(conn, method, path, body, headers) do
    case Mint.HTTP.request(conn, method, path, headers, body) do
      {:ok, conn, request_ref} ->
        struct!(__MODULE__, conn: conn, request_ref: request_ref)

      {:error, conn, error}
      when is_exception(error, Mint.HTTPError) or is_exception(error, Mint.TransportError) ->
        {:error, struct!(__MODULE__, conn: conn),
         HTTPError.new(message: error.reason, adapter_specific_error: error)}
    end
  end

  defp next_fun({:error, state, error}), do: {[error], {:halt, state}}

  defp next_fun({:halt, state}), do: {:halt, state}

  defp next_fun(%{request_ref: request_ref} = state) do
    receive do
      message when Mint.HTTP.is_connection_message(state.conn, message) ->
        {:ok, conn, responses} = Mint.HTTP.stream(state.conn, message)

        case Enum.reverse(responses) do
          [{:done, ^request_ref} | other_responses] ->
            {Enum.map(other_responses, &map_responses/1), {:halt, state}}

          _ ->
            {Enum.map(responses, &map_responses/1), struct!(state, conn: conn)}
        end

      _other ->
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
