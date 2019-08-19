defmodule K8s.Conn.Auth.Token do
  @moduledoc """
  Token based cluster authentication
  """

  @behaviour K8s.Conn.Auth

  defstruct [:token]
  @type t :: %__MODULE__{token: binary}

  @impl true
  @spec create(map() | any, String.t() | any) :: K8s.Conn.Auth.Token.t() | nil
  def create(%{"token" => token}, _), do: %K8s.Conn.Auth.Token{token: token}
  def create(_, _), do: nil

  defimpl K8s.Conn.RequestOptions, for: __MODULE__ do
    @doc "Generates HTTP Authorization options for certificate authentication"
    @spec generate(K8s.Conn.Auth.Token.t()) :: K8s.Conn.RequestOptions.generate_t()
    def generate(%K8s.Conn.Auth.Token{token: token}) do
      {:ok,
       %K8s.Conn.RequestOptions{
         headers: [{"Authorization", "Bearer #{token}"}],
         ssl_options: []
       }}
    end
  end
end
