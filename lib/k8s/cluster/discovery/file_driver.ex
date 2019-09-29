defmodule K8s.Cluster.Discovery.FileDriver do
  @moduledoc """
  `K8s.Cluster.Discovery.Driver` implementation that returns kubernetes API features from file


  """
  @behaviour K8s.Cluster.Discovery.Driver

  @impl true
  def api_versions(_cluster, opts \\ []) do
    file = opts[:path] || path_for(:api_versions_path)
    parse_json(file)
  end

  @impl true
  def resource_definitions(_cluster, opts \\ []) do
    file = opts[:path] || path_for(:resource_definitions_path)
    parse_json(file)
  end

  @spec parse_json(binary()) :: {:ok, list() | map()} | {:error, atom()}
  defp parse_json(nil), do: {:error, :file_not_found}

  defp parse_json(file) do
    with json <- File.read!(file),
         data <- Jason.decode!(json) do
      {:ok, data}
    end
  end

  @spec path_for(atom) :: nil | binary()
  defp path_for(file) do
    opts = Application.get_env(:k8s, :discovery_opts, %{})
    opts[file]
  end
end
