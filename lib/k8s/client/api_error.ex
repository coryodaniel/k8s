defmodule K8s.Client.APIError do
  @moduledoc """
  Kubernetes API Error

  Any HTTP Error with JSON error payload
  """

  defexception message: nil, reason: nil
  @type t :: %__MODULE__{message: String.t(), reason: String.t()}
  @spec message(__MODULE__.t()) :: String.t()
  def message(%__MODULE__{message: message}), do: message

  # Kubernetes specific errors are typically wrapped in a JSON body
  # see: https://github.com/kubernetes/apimachinery/blob/master/pkg/api/errors/errors.go
  # so one must differentiate between e.g ordinary 404s and kubernetes 404
  @spec from_kubernetes_error(map) :: {:error, __MODULE__.t()}
  def from_kubernetes_error(%{"reason" => reason, "message" => message}) do
    err = %__MODULE__{message: message, reason: reason}
    {:error, err}
  end

  def from_kubernetes_error(%{"status" => "Failure", "message" => message}) do
    err = %__MODULE__{message: message, reason: "Failure"}
    {:error, err}
  end
end
