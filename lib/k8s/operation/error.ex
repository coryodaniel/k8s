defmodule K8s.Operation.Error do
  defexception message: nil
  @type t :: %__MODULE__{message: String.t()}
  @spec message(__MODULE__.t()) :: String.t()
  def message(%__MODULE__{message: message}), do: message
end
