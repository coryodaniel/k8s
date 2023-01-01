defmodule K8s.Client.Mint.Request.Upgrade do
  @moduledoc """
  Represents a HTTP to WebSocket upgrade state.

  ### Fields

  - `:caller` - For all types of requests: The calling process.
  - `:websocket_request` - Once upgraded, this becomes the new request struct.
  - `:response` - The response containing received parts.
  """
  alias K8s.Client.Mint.Request.WebSocket, as: WebSocketRequest

  @type t :: %__MODULE__{
          caller: pid() | nil,
          websocket_request: WebSocketRequest.t(),
          response: %{}
        }

  defstruct [:caller, :websocket_request, response: %{}]

  @spec new(keyword()) :: t()
  def new(fields), do: struct!(__MODULE__, fields)
end
