defmodule K8s.Conn.Auth.BasicAuth do
  @moduledoc """
  basic auth cluster authentication
  """

  @behaviour K8s.Conn.Auth

  defstruct [:token]
  @type t :: %__MODULE__{token: binary}

  @impl true
  @spec create(map(), String.t()) :: {:ok, t()} | :skip
  def create(%{"username" => username, "password" => password}, _) do
    {:ok, %__MODULE__{token: Base.encode64("#{username}:#{password}")}}
  end

  def create(_, _), do: :skip

  defimpl K8s.Conn.RequestOptions, for: K8s.Conn.Auth.BasicAuth do
    @doc "Generates HTTP Authorization options for basic auth authentication"
    @spec generate(K8s.Conn.Auth.BasicAuth.t()) :: K8s.Conn.RequestOptions.generate_t()
    def generate(%K8s.Conn.Auth.BasicAuth{token: token}) do
      {:ok,
       %K8s.Conn.RequestOptions{
         headers: [{:Authorization, "Basic #{token}"}],
         ssl_options: []
       }}
    end
  end
end
