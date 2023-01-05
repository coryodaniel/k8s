defmodule K8s.Client.Mint.WebSocket do
  @moduledoc """
  Websocket implementation of Mint based `K8s.Client.Provider`
  """

  alias K8s.Client.Mint.ConnectionRegistry
  alias K8s.Client.Mint.HTTPAdapter
  alias K8s.Client.Provider

  require Mint.HTTP

  @type t :: %__MODULE__{
          conn: Mint.HTTP.t(),
          ref: Mint.Types.request_ref() | nil,
          websocket: Mint.WebSocket.t() | nil
        }

  defstruct [:conn, :ref, :websocket]

  @spec request(uri :: URI.t(), headers :: list(), http_opts :: keyword()) ::
          Provider.websocket_response_t()
  def request(uri, headers, http_opts) do
    {opts, path, headers} = prepare_args(uri, headers, http_opts)

    with {:ok, %{adapter: adapter_pid}} <- ConnectionRegistry.checkout({uri, opts}) do
      HTTPAdapter.websocket_request(adapter_pid, path, headers)
    end
  end

  @spec stream(uri :: URI.t(), headers :: list(), http_opts :: keyword()) ::
          Provider.stream_response_t()
  def stream(uri, headers, http_opts) do
    {opts, path, headers} = prepare_args(uri, headers, http_opts)

    with {:ok, %{adapter: adapter_pid}} <- ConnectionRegistry.checkout({uri, opts}),
         {:ok, request_ref} <- HTTPAdapter.websocket_stream(adapter_pid, path, headers) do
      stream =
        Stream.resource(
          fn -> request_ref end,
          fn
            {:halt, nil} ->
              {:halt, nil}

            request_ref ->
              case HTTPAdapter.next_buffer(adapter_pid, request_ref) do
                {:cont, data} -> {data, request_ref}
                {:halt, data} -> {data, {:halt, nil}}
              end
          end,
          fn _ ->
            HTTPAdapter.stop(adapter_pid)
            nil
          end
        )

      {:ok, stream}
    end
  end

  @spec stream_to(uri :: URI.t(), headers :: list(), http_opts :: keyword(), stream_to :: pid()) ::
          Provider.stream_to_response_t()
  def stream_to(uri, headers, http_opts, stream_to) do
    {opts, path, headers} = prepare_args(uri, headers, http_opts)

    with {:ok, %{adapter: adapter_pid, pool: pool}} <-
           ConnectionRegistry.checkout({uri, opts}) do
      HTTPAdapter.websocket_stream_to(adapter_pid, path, headers, pool, stream_to)
    end
  end

  @spec prepare_args(uri :: URI.t(), headers :: list(), http_opts :: keyword()) ::
          {keyword(), binary(), list()}
  defp prepare_args(uri, headers, http_opts) do
    opts = [transport_opts: Keyword.fetch!(http_opts, :ssl), protocols: [:http1]]
    path = K8s.Client.Mint.HTTP.uri_to_path(uri)
    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)
    {opts, path, headers}
  end
end
