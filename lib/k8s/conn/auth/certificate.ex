defmodule K8s.Conn.Auth.Certificate do
  @moduledoc """
  Certificate based cluster authentication.
  """

  @behaviour K8s.Conn.Auth

  alias K8s.Conn
  alias K8s.Conn.Auth.CertificateWorker
  alias K8s.Conn.Error
  alias K8s.Conn.PKI

  defstruct [:certificate, :key, target: nil]
  @type t :: %__MODULE__{certificate: binary, key: binary, target: GenServer.server() | nil}

  @impl true
  @spec create(map(), String.t()) :: {:ok, t()} | {:error, Error.t()} | :skip
  def create(%{"client-certificate" => cert_file, "client-key" => key_file}, base_path) do
    # If we have a path periodically refresh the certificate and key
    # since cloud providers often rotate these on the order of
    # minutes to hours.
    cert_path = Conn.resolve_file_path(cert_file, base_path)
    key_path = Conn.resolve_file_path(key_file, base_path)

    name = CertificateWorker.via_tuple(cert_path, key_path)
    opts = [cert_path: cert_path, key_path: key_path, name: name]

    # Check to make sure the files exist and are readable
    with {:ok, _stat} <- File.stat(cert_path),
         {:ok, _stat} <- File.stat(key_path),
         {:ok, _pid} <-
           DynamicSupervisor.start_child(
             K8s.Conn.Auth.ProviderSupervisor,
             {CertificateWorker, opts}
           ) do
      {:ok, %__MODULE__{target: name}}
    else
      # More than one connection can be started with the same certificate and key
      # we don't need to read multiple copies of the same file
      {:error, {:already_started, _}} ->
        {:ok, %__MODULE__{target: name}}

      {:error, _reason} = error ->
        error
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
    def generate(%K8s.Conn.Auth.Certificate{target: name}) when not is_nil(name) do
      # When we have a pid we can ask the worker for the current cert and key as it's the most up to date
      with {:ok, %{cert: cert, key: key}} <- CertificateWorker.get_cert_and_key(name) do
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
