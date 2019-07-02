defmodule K8s.Cluster.Discovery.FileDriver do
  @moduledoc """
  `K8s.Cluster.Discovery.Driver` implementation that returns kubernetes API features from file
  """
  @behaviour K8s.Cluster.Discovery.Driver

  @api_versions_path "test/support/discovery_api_versions.json"
  @resource_definitions_path "test/support/discovery_resource_definitions.json"

  @impl true
  def api_versions(_cluster, _opts \\ []), do: parse_json(@api_versions_path)

  @impl true
  def resource_definitions(_cluster, _opts \\ []), do: parse_json(@resource_definitions_path)

  @spec parse_json(binary()) :: {:ok, list() | map()} | {:error, atom()}
  defp parse_json(file) do
    with {:ok, json} <- File.read(file),
         {:ok, data} <- Jason.decode(json) do
      {:ok, data}
    end
  end
end
