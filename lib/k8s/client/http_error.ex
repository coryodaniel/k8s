defmodule K8s.Client.HTTPError do
  @moduledoc """
  Kubernetes API Error

  Any HTTP Error with JSON error payload
  """

  defexception message: nil, adapter_specific_error: nil
  @type t :: %__MODULE__{message: String.t(), adapter_specific_error: any()}

  @spec new(keyword()) :: t()
  def new(fields), do: struct!(__MODULE__, fields)

  @spec from_exception(Exception.t()) :: t()
  def from_exception(exception) do
    new(message: Exception.message(exception), adapter_specific_error: exception)
  end

  @spec message(__MODULE__.t()) :: String.t()
  def message(%__MODULE__{message: message}), do: message
end
