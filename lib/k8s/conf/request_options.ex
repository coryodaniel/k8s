defprotocol K8s.Conf.RequestOptions do
  @moduledoc """
  Encapsulates HTTP request options for an authentication provider.
  """

  @fallback_to_any true

  @typedoc """
  HTTP Request options
  """
  @type t :: %__MODULE__{headers: list(), ssl_options: keyword()}
  defstruct headers: [], ssl_options: []

  @spec generate(any()) :: K8s.Conf.RequestOptions.t()
  def generate(auth)
end

defimpl K8s.Conf.RequestOptions, for: Map do
  @spec generate(map()) :: K8s.Conf.RequestOptions.t()
  def generate(map), do: struct(K8s.Conf.RequestOptions, map)
end

defimpl K8s.Conf.RequestOptions, for: Any do
  @spec generate(any()) :: K8s.Conf.RequestOptions.t()
  def generate(_), do: %K8s.Conf.RequestOptions{}
end
