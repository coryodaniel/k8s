defmodule K8s.Conn.Auth.Azure do
  @moduledoc """
  `auth-provider` for azure
  """
  alias K8s.Conn.RequestOptions

  require Logger
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
              "apiserver-id" => apiserver_id
            },
            "name" => "azure"
          }
        },
        _
      ) do
    if DateTime.diff(DateTime.utc_now(), parse_expires(expires_on)) >= 0 do
      Logger.info(
        "Azure token expired, using refresh token get new access, this will stop working when refresh token expires"
      )

      {:ok, %__MODULE__{token: refresh_token(tenant, refresh_token, client_id, apiserver_id)}}
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

  @spec refresh_token(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def refresh_token(tenant, refresh_token, client_id, _apiserver_id) do
    payload =
      URI.encode_query(%{
        "client_id" => client_id,
        "grant_type" => "refresh_token",
        "refresh_token" => refresh_token
      })

    {:ok, res} =
      K8s.Client.MintHTTPProvider.request(
        :post,
        URI.new!("https://login.microsoftonline.com/#{tenant}/oauth2/v2.0/token"),
        payload,
        [
          {
            "Content-Type",
            "application/x-www-form-urlencoded"
          }
        ],
        ssl: []
      )

    Map.get(res, "access_token")
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
