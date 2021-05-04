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

  @doc """
  Reads the certificate from PEM file or base64 encoding
  """
  @spec cert_from_map(map(), String.t()) :: binary
  def cert_from_map(%{"certificate-authority-data" => data}, _) when not is_nil(data),
    do: PKI.cert_from_base64(data)

  def cert_from_map(%{"certificate-authority" => file_name}, base_path) do
    file_name
    |> Conn.resolve_file_path(base_path)
    |> PKI.cert_from_pem()
  end

  # Handles the case for docker-for-desktop kubernetes cluster as there is no ca
  def cert_from_map(_, _), do: nil

  @doc """
  Reads the certificate from a PEM file
  """
  @spec cert_from_pem(String.t()) :: nil | binary
  def cert_from_pem(nil), do: nil

  def cert_from_pem(file) do
    file
    |> File.read!()
    |> decode_cert_data()
  end

  @doc """
  Decodes the certificate from a base64 encoded string
  """
  @spec cert_from_base64(String.t()) :: nil | binary
  def cert_from_base64(nil), do: nil

  def cert_from_base64(data) do
    case Base.decode64(data) do
      {:ok, cert_data} -> decode_cert_data(cert_data)
      _ -> nil
    end
  end

  defp decode_cert_data(cert_data) do
    cert_data
    |> :public_key.pem_decode()
    |> Enum.find_value(fn
      {:Certificate, data, _} -> data
      _ -> nil
    end)
  end

  @spec private_key_from_pem(String.t()) :: nil | {atom, binary}
  def private_key_from_pem(nil), do: nil

  @doc """
  Reads private key from a PEM file
  """
  def private_key_from_pem(file) do
    file
    |> File.read!()
    |> decode_private_key_data
  end

  @doc """
  Decodes private key from a base64 encoded string
  """
  @spec private_key_from_base64(String.t()) :: nil | {atom, binary}
  def private_key_from_base64(nil), do: nil

  def private_key_from_base64(encoded_key) do
    case Base.decode64(encoded_key) do
      {:ok, data} -> decode_private_key_data(data)
      _ -> nil
    end
  end

  defp decode_private_key_data(private_key_data) do
    private_key_data
    |> :public_key.pem_decode()
    |> Enum.find_value(fn
      {type, data, _} when type in @private_key_atoms -> {type, data}
      _ -> false
    end)
  end
end
