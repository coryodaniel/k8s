defmodule K8s.Client.Mint.WebSocket do
  @moduledoc """
  Websocket implementation of Mint based `K8s.Client.Provider`
  """

  alias K8s.Client.Mint.HTTPAdapter
  alias K8s.Client.Provider

  require Mint.HTTP

  @type t :: %__MODULE__{
          conn: Mint.HTTP.t(),
          ref: Mint.Types.request_ref() | nil,
          websocket: Mint.WebSocket.t() | nil
        }

  defstruct [:conn, :ref, :websocket]

  @spec request(
          uri :: URI.t(),
          headers :: list(),
          http_opts :: keyword()
        ) :: Provider.websocket_response_t()
  def request(uri, headers, http_opts) do
    {opts, path, headers} = prepare_args(uri, headers, http_opts)

    {:ok, adapter_pid} =
      DynamicSupervisor.start_child(
        K8s.Client.Mint.ConnectionSupervisor,
        {HTTPAdapter, {uri, opts}}
      )

    HTTPAdapter.websocket_request(adapter_pid, path, headers)
  end

  @spec stream(
          uri :: URI.t(),
          headers :: list(),
          http_opts :: keyword()
        ) :: Provider.stream_response_t()
  def stream(uri, headers, http_opts) do
    {opts, path, headers} = prepare_args(uri, headers, http_opts)

    {:ok, adapter_pid} =
      DynamicSupervisor.start_child(
        K8s.Client.Mint.ConnectionSupervisor,
        {HTTPAdapter, {uri, opts}}
      )

    HTTPAdapter.websocket_stream(adapter_pid, path, headers)
  end

  @spec stream_to(
          uri :: URI.t(),
          headers :: list(),
          http_opts :: keyword(),
          stream_to :: pid()
        ) :: Provider.stream_to_response_t()
  def stream_to(uri, headers, http_opts, stream_to) do
    {opts, path, headers} = prepare_args(uri, headers, http_opts)

    {:ok, adapter_pid} =
      DynamicSupervisor.start_child(
        K8s.Client.Mint.ConnectionSupervisor,
        {HTTPAdapter, {uri, opts}}
      )

    HTTPAdapter.websocket_stream_to(adapter_pid, path, headers, stream_to)
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
