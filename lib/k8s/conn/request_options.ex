defprotocol K8s.Conn.RequestOptions.Generator do
  @moduledoc """
  Generates `K8s.Conn.RequestOptions` for an authentication provider.
  """

  @fallback_to_any true

  @spec generate(any()) :: K8s.Conn.RequestOptions.generate_t()
  def generate(auth)
end

defmodule K8s.Conn.RequestOptions do
  @moduledoc """
  Encapsulates HTTP request options for an authentication provider.
  """

  @typedoc """
  HTTP Request options
  """
  @type t :: %__MODULE__{headers: keyword(), ssl_options: keyword()}
  defstruct headers: [], ssl_options: []

  @typedoc """
  `generate/1` response type
  """
  @type generate_t :: {:ok, t} | {:error, K8s.Conn.Error.t() | atom}

  @doc """
  Generates request options for the given authentication provider.

  Delegates to the `K8s.Conn.RequestOptions.Generator` protocol.
  """
  @spec generate(any()) :: generate_t()
  defdelegate generate(auth), to: K8s.Conn.RequestOptions.Generator
end

defimpl K8s.Conn.RequestOptions.Generator, for: Map do
  @spec generate(map()) :: K8s.Conn.RequestOptions.generate_t()
  def generate(map), do: {:ok, struct(K8s.Conn.RequestOptions, map)}
end

defimpl K8s.Conn.RequestOptions.Generator, for: Any do
  @spec generate(any()) :: K8s.Conn.RequestOptions.generate_t()
  def generate(_), do: {:ok, %K8s.Conn.RequestOptions{}}
end
