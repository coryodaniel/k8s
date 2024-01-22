defmodule K8s.Conn.Auth.Certificate do
  @moduledoc """
  Certificate based cluster authentication.
  """

  @behaviour K8s.Conn.Auth

  alias K8s.Conn
  alias K8s.Conn.Auth.CertificateWorker
  alias K8s.Conn.Error
  alias K8s.Conn.PKI

  defstruct [:certificate, :key, pid: nil]
  @type t :: %__MODULE__{certificate: binary, key: binary, pid: pid() | nil}

  @impl true
  @spec create(map(), String.t()) :: {:ok, t()} | {:error, Error.t()} | :skip
  def create(%{"client-certificate" => cert_file, "client-key" => key_file}, base_path) do
    cert_path = Conn.resolve_file_path(cert_file, base_path)
    key_path = Conn.resolve_file_path(key_file, base_path)

    # If we have a path periodically refresh the certificate and key
    # since cloud providers often rotate these on the order of
    # minutes to hours.
    with {:ok, pid} <-
           DynamicSupervisor.start_child(
             K8s.Conn.Auth.ProviderSupervisor,
             {CertificateWorker, cert_path: cert_path, key_path: key_path}
           ) do
      {:ok, %K8s.Conn.Auth.Certificate{pid: pid}}
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
    def generate(%K8s.Conn.Auth.Certificate{pid: pid}) when not is_nil(pid) do
      # When we have a pid we can ask the worker for the current cert and key as it's the most up to date
      with {:ok, %{cert: cert, key: key}} <- CertificateWorker.get_cert_and_key(pid) do
        {:ok,
         %K8s.Conn.RequestOptions{
           headers: [],
           ssl_options: [cert: cert, key: key]
         }}
      end
    end

    def generate(%K8s.Conn.Auth.Certificate{certificate: certificate, key: key}) do
      # We have a cached certificate and key use those
      {:ok,
       %K8s.Conn.RequestOptions{
         headers: [],
         ssl_options: [cert: certificate, key: key]
       }}
    end
  end
end
