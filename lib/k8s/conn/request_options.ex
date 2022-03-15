defprotocol K8s.Conn.RequestOptions do
  @moduledoc """
  Encapsulates HTTP request options for an authentication provider.
  """

  @fallback_to_any true

  @typedoc """
  HTTP Request options
  """
  @type t :: %__MODULE__{headers: keyword(), ssl_options: keyword()}
  defstruct headers: [], ssl_options: []

  @typedoc """
  `generate/1` response type
  """
  @type generate_t :: {:ok, t} | {:error, K8s.Conn.Error.t() | atom}

  @spec generate(any()) :: generate_t()
  def generate(auth)
end

defimpl K8s.Conn.RequestOptions, for: Map do
  @spec generate(map()) :: K8s.Conn.RequestOptions.generate_t()
  def generate(map), do: {:ok, struct(K8s.Conn.RequestOptions, map)}
end

defimpl K8s.Conn.RequestOptions, for: Any do
  @spec generate(any()) :: K8s.Conn.RequestOptions.generate_t()
  def generate(_), do: {:ok, %K8s.Conn.RequestOptions{}}
end
