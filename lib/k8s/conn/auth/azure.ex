defmodule K8s.Conn.Auth.Azure do
  @moduledoc """
  `auth-provider` for azure
  """
  alias K8s.Conn.RequestOptions
  alias K8s.Conn.Error
  @behaviour K8s.Conn.Auth

  defstruct [:token]

  @type t :: %__MODULE__{
          token: String.t()
        }

  @impl true
  @spec create(map, String.t()) :: {:ok, t} | :skip
  def create(
        %{
          "auth-provider" => %{
            "config" => %{
              "access-token" => token,
              "tenant-id" => _tenant,
              "expires-on" => expires_on,
              "refresh-token" => _refresh_token,
              "client-id" => _client_id,
              "apiserver-id" => _apiserver_id
            },
            "name" => "azure"
          }
        },
        _
      ) do
    if parse_expires(expires_on) <= DateTime.utc_now() do
      {:error, %Error{message: "Azure token expired please refresh manually"}}
    else
      {:ok, %__MODULE__{token: token}}
    end
  end

  def create(_, _), do: :skip

  @spec parse_expires(String.t()) :: DateTime.t()
  defp parse_expires(expires_on) do
    case Integer.parse(expires_on) do
      {expires_on, _} -> DateTime.from_unix!(expires_on)
      :error -> DateTime.from_iso8601(expires_on)
    end
  end

  defimpl RequestOptions, for: __MODULE__ do
    @spec generate(K8s.Conn.Auth.Azure.t()) :: RequestOptions.generate_t()
    def generate(%K8s.Conn.Auth.Azure{token: token}) do
      {:ok,
       %RequestOptions{
         headers: [{:Authorization, "Bearer #{token}"}],
         ssl_options: []
       }}
    end
  end
end
