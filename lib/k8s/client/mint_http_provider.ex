defmodule K8s.Client.MintHTTPProvider do
  @moduledoc """
  Mint based `K8s.Client.Provider`
  """
  @behaviour K8s.Client.Provider

  alias K8s.Client.Mint.ConnectionRegistry
  alias K8s.Client.Mint.HTTPAdapter
  require Logger

  @data_types [:data, :stdout, :stderr, :error]

  @impl true
  def request(method, uri, body, headers, http_opts) do
    with {:ok, stream} <- stream(method, uri, body, headers, http_opts) do
      response =
        stream
        |> Stream.reject(&(&1 == {:done, true}))
        |> Enum.reduce(%{data: []}, fn
          {:data, data}, response -> Map.update!(response, :data, &[data | &1])
          {type, value}, response -> Map.put(response, type, value)
        end)

      response
      |> Map.update!(:data, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> process_response()
    end
  end

  @impl true
  def stream(method, uri, body, headers, http_opts) do
    with :ok <- stream_to(method, uri, body, headers, http_opts, self()) do
      stream =
        Stream.unfold(:pending, fn :pending ->
          receive do
            {:done, true} -> nil
            other -> {other, :pending}
          end
        end)

      {:ok, stream}
    end
  end

  @impl true
  def stream_to(method, uri, body, headers, http_opts, stream_to) do
    opts = [transport_opts: Keyword.fetch!(http_opts, :ssl)]
    method = String.upcase("#{method}")
    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)
    path = uri_to_path(uri)

    with {:ok, %{adapter: adapter_pid, pool: pool}} <-
           ConnectionRegistry.checkout({uri, opts}) do
      HTTPAdapter.stream_to(adapter_pid, method, path, headers, body, pool, stream_to)
    end
  end

  @impl true
  def websocket_request(uri, headers, http_opts) do
    with {:ok, stream} <- websocket_stream(uri, headers, http_opts) do
      response =
        stream
        |> Stream.reject(&(&1 == {:done, true}))
        |> Enum.reduce(%{}, fn
          {type, data}, response when type in @data_types ->
            Map.update(response, type, [data], &[data | &1])

          {type, value}, response ->
            Map.put(response, type, value)
        end)

      response =
        @data_types
        |> Enum.reduce(response, fn type, response ->
          Map.update(response, type, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
        end)
        |> Map.reject(&(&1 |> elem(1) |> is_nil()))

      {:ok, response}
    end
  end

  @impl true
  def websocket_stream(uri, headers, http_opts) do
    with {:ok, _} <- websocket_stream_to(uri, headers, http_opts, self()) do
      stream =
        Stream.unfold(:open, fn
          :close ->
            nil

          :open ->
            receive do
              {:close, data} -> {{:close, data}, :close}
              other -> {other, :open}
            end
        end)

      {:ok, stream}
    end
  end

  @impl true
  def websocket_stream_to(uri, headers, http_opts, stream_to) do
    opts = [transport_opts: Keyword.fetch!(http_opts, :ssl), protocols: [:http1]]
    path = uri_to_path(uri)
    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)

    with {:ok, %{adapter: adapter_pid, pool: pool}} <-
           ConnectionRegistry.checkout({uri, opts}) do
      HTTPAdapter.websocket_stream_to(adapter_pid, path, headers, pool, stream_to)
    end
  end

  @spec process_response(map()) :: K8s.Client.Provider.response_t()
  defp process_response(%{status: status} = response) when status in 400..599 do
    %{data: data, headers: headers, status: status_code} = response

    case get_content_type(headers) do
      "application/json" = content_type ->
        data
        |> decode(content_type)
        |> K8s.Client.APIError.from_kubernetes_error()

      _other ->
        {:error, K8s.Client.HTTPError.new(message: "HTTP Error #{status_code}")}
    end
  end

  defp process_response(response) do
    content_type = get_content_type(response.headers)
    body = response.data |> decode(content_type)

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
      {:ok, data} ->
        data

      {:error, error} ->
        Logger.error("The response body is supposed to be JSON but could not be decoded.",
          library: :k8s,
          error: error
        )

        nil
    end
  end

  @spec uri_to_path(URI.t()) :: binary()
  defp uri_to_path(uri) do
    path =
      IO.iodata_to_binary([
        uri.path,
        if(uri.query, do: ["?" | uri.query], else: [])
      ])

    String.trim(path, "?")
  end
end
