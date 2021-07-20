defmodule K8s.Client.APIError do
  @moduledoc """
  Kubernetes API Error

  Any HTTP Error with JSON error payload
  """

  defexception message: nil, reason: nil
  @type t :: %__MODULE__{message: String.t(), reason: String.t()}
  @spec message(__MODULE__.t()) :: String.t()
  def message(%__MODULE__{message: message}), do: message
end
