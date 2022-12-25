defmodule K8s.Client.Mint.UpgradeRequest do
  @type t :: %__MODULE__{}

  defstruct [:from, :websocket_request, response: %{}]

  @spec new(keyword()) :: t()
  def new(fields), do: struct!(__MODULE__, fields)
end
