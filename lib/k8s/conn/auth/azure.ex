defmodule K8s.Conn.Auth.Azure do
  @moduledoc """
  `auth-provider` for azure
  """
  alias K8s.Conn.RequestOptions
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
              "tenant-id" => tenant,
              "expires-on" => expires_on,
              "refresh-token" => refresh_token,
              "client-id" => client_id,
              "apiserver-id" => _apiserver_id
            },
            "name" => "azure"
          }
        },
        _
      ) do
    if parse_expires(expires_on) <= DateTime.utc_now() do
      # TODO current we don't have access to the credential file, so we wont be able to write the refresh token back into this, hence we will request a new token on every request when the original has expired
      {:ok,
       %__MODULE__{
         token: refresh_token(tenant, refresh_token, client_id)
       }}
    else
      {:ok,
       %__MODULE__{
         token: token
       }}
    end
  end

  def create(_, _), do: :skip

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

  defp refresh_token(
         tenant,
         refresh_token,
         client_id
       ) do
    payload =
      URI.encode_query(%{
        "client_id" => client_id,
        "grant_type" => "refresh_token",
        "refresh_token" => refresh_token
      })

    HTTPoison.post!(
      "https://login.microsoftonline.com/#{tenant}/oauth2/v2.0/token",
      payload,
      %{
        "Content-Type" => "application/x-www-form-urlencoded"
      }
    ).body
    |> Jason.decode!()
    |> Map.get("access_token")
  end
end
