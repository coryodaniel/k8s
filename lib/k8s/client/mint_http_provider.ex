defmodule K8s.Client.MintHTTPProvider do
  @moduledoc """
  Mint based `K8s.Client.Provider`
  """
  @behaviour K8s.Client.Provider
  require Logger
  require Mint.HTTP

  @type t :: %__MODULE__{
          conn: Mint.HTTP.t(),
          request_ref: Mint.Types.request_ref() | nil,
          websocket: Mint.WebSocket.t() | nil
        }

  defstruct [:conn, :request_ref, :websocket]

  @impl true
  defdelegate request(method, uri, body, headers, http_opts), to: K8s.Client.Mint.HTTP

  @impl true
  defdelegate stream(method, uri, body, headers, http_opts), to: K8s.Client.Mint.HTTP

  @impl true
  defdelegate websocket_stream(uri, headers, http_opts),
    to: K8s.Client.Mint.WebSocket,
    as: :stream

  @impl true
  defdelegate websocket_request(uri, headers, http_opts),
    to: K8s.Client.Mint.WebSocket,
    as: :request
end
