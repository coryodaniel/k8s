defmodule K8s.Client.Mint.HTTP do
  @moduledoc """
  HTTP request implementation of Mint based `K8s.Client.Provider`
  """

  alias K8s.Client.Mint.ConnectionRegistry
  alias K8s.Client.Mint.HTTPAdapter
  alias K8s.Client.Provider

  require Logger
  require Mint.HTTP

  @type t :: %__MODULE__{
          conn: Mint.HTTP.t(),
          request_ref: Mint.Types.request_ref() | nil
        }

  @typep request_response_t :: map()

  defstruct [:conn, :request_ref]

  @spec request(
          method :: atom(),
          uri :: URI.t(),
          body :: binary,
          headers :: list(),
          http_opts :: keyword()
        ) :: Provider.response_t()
  def request(method, uri, body, headers, http_opts) do
    {method, path, headers, opts} = prepare_args(method, uri, headers, http_opts)

    ConnectionRegistry.run({uri, opts}, fn adapter_pid ->
      with {:ok, response} <-
             HTTPAdapter.request(adapter_pid, method, path, headers, body) do
        process_response(response)
      end
    end)
  end

  @spec stream(
          method :: atom(),
          uri :: URI.t(),
          body :: binary,
          headers :: list(),
          http_opts :: keyword()
        ) :: Provider.stream_response_t()
  def stream(method, uri, body, headers, http_opts) do
    {method, path, headers, opts} = prepare_args(method, uri, headers, http_opts)

    with {:ok, %{adapter: adapter_pid} = pool_worker} <- ConnectionRegistry.checkout({uri, opts}),
         {:ok, request_ref} <- HTTPAdapter.stream(adapter_pid, method, path, headers, body) do
      stream =
        Stream.resource(
          fn -> request_ref end,
          fn
            {:halt, request_ref} ->
              {:halt, request_ref}

            request_ref ->
              case HTTPAdapter.next_buffer(adapter_pid, request_ref) do
                {:cont, data} -> {data, request_ref}
                {:halt, data} -> {data, {:halt, request_ref}}
              end
          end,
          fn request_ref ->
            HTTPAdapter.terminate_request(adapter_pid, request_ref)
            ConnectionRegistry.checkin(pool_worker)
          end
        )

      {:ok, stream}
    end
  end

  @spec stream_to(
          method :: atom(),
          uri :: URI.t(),
          body :: binary,
          headers :: list(),
          http_opts :: keyword(),
          stream_to :: pid()
        ) :: Provider.stream_to_response_t()
  def stream_to(method, uri, body, headers, http_opts, stream_to) do
    {method, path, headers, opts} = prepare_args(method, uri, headers, http_opts)

    with {:ok, %{adapter: adapter_pid, pool: pool}} <-
           ConnectionRegistry.checkout({uri, opts}) do
      HTTPAdapter.stream_to(adapter_pid, method, path, headers, body, pool, stream_to)
    end
  end

  @spec process_response(request_response_t()) :: K8s.Client.Provider.response_t()
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
  def uri_to_path(uri) do
    path =
      IO.iodata_to_binary([
        uri.path,
        if(uri.query, do: ["?" | uri.query], else: [])
      ])

    String.trim(path, "?")
  end

  @spec prepare_args(
          method :: atom(),
          uri :: URI.t(),
          headers :: list(),
          http_opts :: keyword()
        ) :: {binary(), binary(), list(), keyword()}
  defp prepare_args(method, uri, headers, http_opts) do
    opts = [transport_opts: Keyword.fetch!(http_opts, :ssl)]
    method = String.upcase("#{method}")
    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)
    path = uri_to_path(uri)
    {method, path, headers, opts}
  end
end
