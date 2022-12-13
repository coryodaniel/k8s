defmodule K8s.Conn.PKI do
  @moduledoc """
  Retrieves information from certificates
  """

  alias K8s.Conn
  alias K8s.Conn.PKI

  @private_key_atoms [
    :RSAPrivateKey,
    :DSAPrivateKey,
    :ECPrivateKey,
    :PrivateKeyInfo
  ]

  @type private_key_data_t :: {atom, binary}

  @doc """
  Reads the certificate from PEM file or base64 encoding
  """
  @spec cert_from_map(map, binary) ::
          {:error, :enoent | K8s.Conn.Error.t()} | {:ok, binary() | nil}
  def cert_from_map(%{"certificate-authority-data" => data}, _) when not is_nil(data),
    do: PKI.cert_from_base64(data)

  def cert_from_map(%{"certificate-authority" => file_name}, base_path)
      when not is_nil(file_name) do
    file_name
    |> Conn.resolve_file_path(base_path)
    |> PKI.cert_from_pem()
  end

  def cert_from_map(_, _), do: {:ok, nil}

  @doc """
  Reads the certificate from a PEM file
  """
  @spec cert_from_pem(String.t()) :: {:ok, binary} | {:error, :enoent | K8s.Conn.Error.t()}
  def cert_from_pem(file) do
    with {:ok, data} <- File.read(file), do: decode_cert_data(data)
  end

  @doc """
  Decodes the certificate from a base64 encoded string
  """
  @spec cert_from_base64(binary) :: {:ok, binary} | {:enoent | K8s.Conn.Error.t()}
  def cert_from_base64(data) do
    with {:ok, data} <- decode64(data) do
      decode_cert_data(data)
    end
  end

  @doc """
  Reads private key from a PEM file
  """
  @spec private_key_from_pem(String.t()) ::
          {:ok, private_key_data_t} | {:error, :enoent | K8s.Conn.Error.t()}
  def private_key_from_pem(file) do
    with {:ok, data} <- File.read(file) do
      decode_private_key_data(data)
    end
  end

  @doc """
  Decodes private key from a base64 encoded string
  """
  @spec private_key_from_base64(String.t()) ::
          {:ok, private_key_data_t} | {:error, K8s.Conn.Error.t()}
  def private_key_from_base64(encoded_key) do
    with {:ok, data} <- decode64(encoded_key) do
      case decode_private_key_data(data) do
        {:ok, private_key_data} -> {:ok, private_key_data}
        error -> error
      end
    end
  end

  @spec decode64(binary) :: {:ok, binary} | {:error, K8s.Conn.Error.t()}
  defp decode64(data) do
    case Base.decode64(data) do
      {:ok, data} -> {:ok, data}
      :error -> {:error, %K8s.Conn.Error{message: "Invalid Base64"}}
    end
  end

  @spec decode_cert_data(binary) :: {:ok, binary} | {:error, K8s.Conn.Error.t()}
  defp decode_cert_data(cert_data) do
    cert_data
    |> :public_key.pem_decode()
    |> Enum.find_value(fn
      {:Certificate, data, _} ->
        {:ok, data}

      _ ->
        {:error, %K8s.Conn.Error{message: "No cert data."}}
    end)
  end

  @spec decode_private_key_data(binary) ::
          {:ok, private_key_data_t} | {:error, K8s.Conn.Error.t()}
  defp decode_private_key_data(private_key_data) do
    private_key_data
    |> :public_key.pem_decode()
    |> Enum.find_value(fn
      {type, data, _} when type in @private_key_atoms ->
        {:ok, {type, data}}

      _ ->
        {:error,
         %K8s.Conn.Error{
           message: "Unsupported PEM data. Supported types #{inspect(@private_key_atoms)}"
         }}
    end)
  end
end
