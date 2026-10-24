defmodule K8s.Yaml.Glazer do
  @moduledoc """
  Adapter that makes `Glazer.YAML` compatible with `:k8s` `yaml_library` callbacks.

  Implements:

  - `read_from_file/1`
  - `read_from_string/1`
  - `read_all_from_string/1`

  `Glazer.YAML` exposes single-document decoding APIs. This adapter implements
  `read_all_from_string/1` by splitting on YAML document separators and decoding
  each document individually.
  """

  @spec read_from_file(binary()) :: {:ok, any()} | {:error, any()}
  def read_from_file(path) do
    with {:ok, contents} <- File.read(path) do
      read_from_string(contents)
    end
  end

  @spec read_from_string(binary()) :: {:ok, any()} | {:error, any()}
  def read_from_string(contents), do: Glazer.YAML.decode(contents)

  @spec read_all_from_string(binary()) :: {:ok, list(any())} | {:error, any()}
  def read_all_from_string(contents) do
    contents
    |> split_yaml_documents()
    |> Enum.reduce_while({:ok, []}, fn document, {:ok, acc} ->
      case read_from_string(document) do
        {:ok, decoded} -> {:cont, {:ok, [decoded | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, docs} -> {:ok, Enum.reverse(docs)}
      error -> error
    end
  end

  @spec split_yaml_documents(binary()) :: list(binary())
  defp split_yaml_documents(contents) do
    Regex.split(~r/^(?:---|\.\.\.)[\t ]*\r?$/m, contents, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
