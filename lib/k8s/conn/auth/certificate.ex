defmodule K8s.Conn.Auth.Certificate do
  @moduledoc """
  Certificate based cluster authentication.
  """

  @behaviour K8s.Conn.Auth

  alias K8s.Conn
  alias K8s.Conn.{Error, PKI}

  defstruct [:certificate, :key]
  @type t :: %__MODULE__{certificate: binary, key: binary}

  @impl true
  @spec create(map(), String.t()) :: {:ok, t()} | {:error, Error.t()} | :skip
  def create(%{"client-certificate" => cert_file, "client-key" => key_file}, base_path) do
    cert_path = Conn.resolve_file_path(cert_file, base_path)
    key_path = Conn.resolve_file_path(key_file, base_path)

    with {:ok, cert} <- PKI.cert_from_pem(cert_path),
         {:ok, key} <- PKI.private_key_from_pem(key_path) do
      {:ok, %K8s.Conn.Auth.Certificate{certificate: cert, key: key}}
    end
  end

  def create(%{"client-certificate-data" => cert_data, "client-key-data" => key_data}, _) do
    with {:ok, cert} <- PKI.cert_from_base64(cert_data),
         {:ok, key} <- PKI.private_key_from_base64(key_data) do
      {:ok, %K8s.Conn.Auth.Certificate{certificate: cert, key: key}}
    end
  end

  def create(_, _), do: :skip

  defimpl K8s.Conn.RequestOptions, for: K8s.Conn.Auth.Certificate do
    @doc "Generates HTTP Authorization options for certificate authentication"
    @spec generate(K8s.Conn.Auth.Certificate.t()) :: K8s.Conn.RequestOptions.generate_t()
    def generate(%K8s.Conn.Auth.Certificate{certificate: certificate, key: key}) do
      {:ok,
       %K8s.Conn.RequestOptions{
         headers: [],
         ssl_options: [cert: certificate, key: key]
       }}
    end
  end
end
