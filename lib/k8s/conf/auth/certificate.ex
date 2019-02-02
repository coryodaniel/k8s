defmodule K8s.Conf.Auth.Certificate do
  @moduledoc """
  Certificate based cluster authentication.
  """

  @behaviour K8s.Conf.Auth
  alias K8s.Conf
  alias K8s.Conf.PKI
  @type t :: %__MODULE__{certificate: binary, key: binary}
  defstruct [:certificate, :key]

  @impl true
  @spec create(map(), String.t()) :: K8s.Conf.Auth.Certificate.t() | nil
  def create(%{"client-certificate" => cert_file, "client-key" => key_file}, base_path) do
    cert_path = Conf.resolve_file_path(cert_file, base_path)
    key_path = Conf.resolve_file_path(key_file, base_path)

    %K8s.Conf.Auth.Certificate{
      certificate: PKI.cert_from_pem(cert_path),
      key: PKI.private_key_from_pem(key_path)
    }
  end

  def create(
        %{
          "client-certificate-data" => cert_data,
          "client-key-data" => key_data
        },
        _
      ) do
    %K8s.Conf.Auth.Certificate{
      certificate: PKI.cert_from_base64(cert_data),
      key: PKI.private_key_from_base64(key_data)
    }
  end

  def create(_, _), do: nil

  defimpl Inspect, for: __MODULE__ do
    import Inspect.Algebra

    def inspect(_auth, _opts) do
      concat(["#Certficate<...>"])
    end
  end

  defimpl K8s.Conf.RequestOptions, for: __MODULE__ do
    @doc "Generates HTTP Authorization options for certificate authentication"
    @spec generate(K8s.Conf.Auth.Certificate.t()) :: K8s.Conf.RequestOptions.t()
    def generate(%K8s.Conf.Auth.Certificate{certificate: certificate, key: key}) do
      %K8s.Conf.RequestOptions{
        headers: [],
        ssl_options: [cert: certificate, key: key]
      }
    end
  end
end
