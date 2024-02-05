defmodule K8s.Conn.Auth.Certificate do
  @moduledoc """
  Certificate based cluster authentication.
  """

  @behaviour K8s.Conn.Auth

  alias K8s.Conn
  alias K8s.Conn.{Error, PKI}

  defstruct [:certificate, :key, :cert_path, :key_path]

  @type t :: %__MODULE__{
          certificate: binary,
          key: binary,
          cert_path: String.t(),
          key_path: String.t()
        }

  @impl true
  @spec create(map(), String.t()) :: {:ok, t()} | {:error, Error.t()} | :skip
  def create(%{"client-certificate" => cert_file, "client-key" => key_file}, base_path) do
    cert_path = Conn.resolve_file_path(cert_file, base_path)
    key_path = Conn.resolve_file_path(key_file, base_path)

    # ensure that something exists at the path.
    # This enables better error messages if there isn't a cert there.
    with {:ok, _cert_stat} <- File.stat(cert_file), {:ok, _key_path} <- File.stat(key_file) do
      {:ok, %K8s.Conn.Auth.Certificate{cert_path: cert_path, key_path: key_path}}
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
    def generate(%K8s.Conn.Auth.Certificate{cert_path: cert_path, key_path: key_path})
        when not is_nil(cert_path) and not is_nil(key_path) do
      # If we have a path then pass that along
      # This allows the underlying HTTP client to handle the file IO
      # and refresh the certificate if it changes.
      # https://www.erlang.org/doc/man/ssl#type-common_option
      {:ok,
       %K8s.Conn.RequestOptions{
         headers: [],
         ssl_options: [certfile: cert_path, keyfile: key_path]
       }}
    end

    def generate(%K8s.Conn.Auth.Certificate{certificate: certificate, key: key}) do
      # If the context contained binary certs then pass them to the ssl client directly.
      {:ok,
       %K8s.Conn.RequestOptions{
         headers: [],
         ssl_options: [cert: certificate, key: key]
       }}
    end
  end
end
