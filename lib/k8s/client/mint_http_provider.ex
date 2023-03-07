defmodule K8s.Client.MintHTTPProvider do
  @moduledoc """
  Mint based `K8s.Client.Provider`
  """
  @behaviour K8s.Client.Provider

  alias K8s.Client.HTTPError
  alias K8s.Client.Mint.ConnectionRegistry
  alias K8s.Client.Mint.HTTPAdapter
  require Logger

  @data_types [:data, :stdout, :stderr, :error]

  @impl true
  def request(method, uri, body, headers, http_opts) do
    with {:ok, stream} <- stream(method, uri, body, headers, http_opts) do
      response =
        stream
        |> Stream.reject(&(&1 == :done))
        |> Enum.reduce(%{data: []}, fn
          {:data, data}, response -> Map.update!(response, :data, &[data | &1])
          {type, value}, response -> Map.put(response, type, value)
          type, response -> Map.put(response, type, true)
        end)

      response
      |> Map.update!(:data, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> process_response()
    end
  end

  @impl true
  def stream(method, uri, body, headers, http_opts) do
    case do_stream_to(method, uri, body, headers, http_opts, nil) do
      {:ok, request_ref, adapter_pid} ->
        stream =
          Stream.resource(
            fn -> :pending end,
            fn
              :pending ->
                parts = HTTPAdapter.recv(adapter_pid, request_ref)
                # credo:disable-for-next-line
                next_state = if :done in parts, do: :done, else: :pending
                {parts, next_state}

              :done ->
                {:halt, :ok}
            end,
            fn _ -> :ok end
          )

        {:ok, stream}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def stream_to(method, uri, body, headers, http_opts, stream_to) do
    with {:ok, _, _} <- do_stream_to(method, uri, body, headers, http_opts, stream_to) do
      :ok
    end
  end

  @spec do_stream_to(
          method :: atom(),
          uri :: URI.t(),
          body :: binary,
          headers :: list(),
          http_opts :: keyword(),
          stream_to :: pid() | nil
        ) :: {:ok, reference(), pid()} | {:error, HTTPError.t()}
  defp do_stream_to(method, uri, body, headers, http_opts, stream_to) do
    opts = [transport_opts: Keyword.fetch!(http_opts, :ssl)]
    method = String.upcase("#{method}")
    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)
    path = uri_to_path(uri)

    with {:ok, %{adapter: adapter_pid, pool: pool}} <- ConnectionRegistry.checkout({uri, opts}),
         {:ok, request_ref} <-
           HTTPAdapter.request(adapter_pid, method, path, headers, body, pool, stream_to) do
      {:ok, request_ref, adapter_pid}
    end
  end

  @impl true
  def websocket_request(uri, headers, http_opts) do
    with {:ok, stream} <- websocket_stream(uri, headers, http_opts) do
      response =
        stream
        |> Stream.reject(&(&1 == :done))
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
    case do_websocket_stream_to(uri, headers, http_opts, self()) do
      {:ok, request_ref, adapter_pid} ->
        stream =
          Stream.resource(
            fn -> :pending end,
            fn
              :pending ->
                parts = HTTPAdapter.recv(adapter_pid, request_ref)

                # credo:disable-for-lines:2
                next_state =
                  if Enum.any?(parts, &(elem(&1, 0) == :close)), do: :done, else: :pending

                {parts, next_state}

              :done ->
                {:halt, :ok}
            end,
            fn _ -> :ok end
          )

        {:ok, stream}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def websocket_stream_to(uri, headers, http_opts, stream_to) do
    with {:ok, request_ref, adapter_pid} <-
           do_websocket_stream_to(uri, headers, http_opts, stream_to) do
      send_to_websocket = fn data ->
        HTTPAdapter.websocket_send(adapter_pid, request_ref, data)
      end

      {:ok, send_to_websocket}
    end
  end

  @spec do_websocket_stream_to(
          uri :: URI.t(),
          headers :: list(),
          http_opts :: keyword(),
          stream_to :: pid() | nil
        ) :: {:ok, reference(), pid()} | {:error, HTTPError.t()}
  defp do_websocket_stream_to(uri, headers, http_opts, stream_to) do
    opts = [transport_opts: Keyword.fetch!(http_opts, :ssl), protocols: [:http1]]
    path = uri_to_path(uri)
    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)

    with {:ok, %{adapter: adapter_pid, pool: pool}} <- ConnectionRegistry.checkout({uri, opts}),
         {:ok, request_ref} <-
           HTTPAdapter.websocket_request(adapter_pid, path, headers, pool, stream_to) do
      {:ok, request_ref, adapter_pid}
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
      {_key, content_type} -> content_type |> String.split(";") |> List.first()
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
          error: error,
          body: body
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
