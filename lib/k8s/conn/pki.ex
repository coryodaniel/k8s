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
          {:error, :no_cert_data | :noent | :not_base64} | {:ok, binary() | nil}
  def cert_from_map(%{"certificate-authority-data" => data}, _) when not is_nil(data),
    do: PKI.cert_from_base64(data)

  def cert_from_map(%{"certificate-authority" => file_name}, base_path)
      when not is_nil(file_name) do
    file_name
    |> Conn.resolve_file_path(base_path)
    |> PKI.cert_from_pem()
  end

  def cert_from_map(%{"insecure-skip-tls-verify" => true}, _), do: {:ok, nil}

  @doc """
  Reads the certificate from a PEM file
  """
  @spec cert_from_pem(String.t()) :: {:ok, binary} | {:error, :noent | :no_cert_data}
  def cert_from_pem(file) do
    with {:ok, data} <- File.read(file), do: decode_cert_data(data)
  end

  @doc """
  Decodes the certificate from a base64 encoded string
  """
  @spec cert_from_base64(binary) :: {:ok, binary} | {:error, :not_base64 | :no_cert_data}
  def cert_from_base64(data) do
    case Base.decode64(data) do
      {:ok, cert_data} ->
        decode_cert_data(cert_data)

      :error ->
        {:error, :not_base64}
    end
  end

  @doc """
  Reads private key from a PEM file
  """
  @spec private_key_from_pem(String.t()) :: {:ok, private_key_data_t} | {:error, binary}
  def private_key_from_pem(file) do
    with {:ok, data} <- File.read(file) do
      case decode_private_key_data(data) do
        {:ok, private_key_data} -> {:ok, private_key_data}
        error -> error
      end
    end
  end

  @doc """
  Decodes private key from a base64 encoded string
  """
  @spec private_key_from_base64(String.t()) ::
          {:ok, private_key_data_t} | {:error, :not_base64 | :unsupported_pem_data}
  def private_key_from_base64(encoded_key) do
    case Base.decode64(encoded_key) do
      {:ok, data} ->
        case decode_private_key_data(data) do
          {:ok, private_key_data} -> {:ok, private_key_data}
          error -> error
        end

      :error ->
        {:error, :not_base64}
    end
  end

  @spec decode_cert_data(binary) :: {:ok, binary} | {:error, :no_cert_data}
  defp decode_cert_data(cert_data) do
    cert_data
    |> :public_key.pem_decode()
    |> Enum.find_value(fn
      {:Certificate, data, _} -> {:ok, data}
      _ -> {:error, :no_cert_data}
    end)
  end

  @spec decode_private_key_data(binary) ::
          {:ok, private_key_data_t} | {:error, :unsupported_pem_data}
  defp decode_private_key_data(private_key_data) do
    private_key_data
    |> :public_key.pem_decode()
    |> Enum.find_value(fn
      {type, data, _} when type in @private_key_atoms -> {:ok, {type, data}}
      _ -> {:error, :unsupported_pem_data}
    end)
  end
end
