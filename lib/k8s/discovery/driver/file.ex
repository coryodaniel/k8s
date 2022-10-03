defmodule K8s.Discovery.Driver.File do
  @moduledoc """
  File Driver for Kubernetes API discovery.

  This module allows API versions and Resources accessible by the k8s to be defined rather than discovered.

  This module is primarily used for testing, but can be used if you wish to hard code supported API versions and resources.

  See [./test/support/discovery/example.json](./test/support/discovery/example.json) for an example.

  ## Examples
    "Discovering" hard coded resources.

      iex> K8s.Discovery.Driver.File.resources("apps/v1", %K8s.Conn{}, config: "./test/support/discovery/example.json")
      [
        %{
          "kind" => "DaemonSet",
          "name" => "daemonsets"
        },
        %{
          "kind" => "Deployment",
          "name" => "deployments"
        },
        %{
          "kind" => "Deployment",
          "name" => "deployments/status"
        }
      ]

    "Discovering" hard coded versions.
      iex> K8s.Discovery.Driver.File.versions(%K8s.Conn{}, config: "./test/support/discovery/example.json")
      ["v1", "apps/v1"]
  """
  @behaviour K8s.Discovery.Driver

  @impl true
  def resources(api_version, %K8s.Conn{} = conn, opts \\ []),
    do: get_resources(api_version, Keyword.merge(conn.discovery_opts, opts))

  @impl true
  def versions(%K8s.Conn{} = conn, opts \\ []),
    do: get_versions(Keyword.merge(conn.discovery_opts, opts))

  @spec get_versions(keyword) :: {:ok, list(binary)} | {:error, :enoent | Jason.DecodeError.t()}
  defp get_versions(opts) do
    with {:ok, config} <- get_config(opts) do
      versions = Map.keys(config)
      {:ok, versions}
    end
  end

  @spec get_resources(binary, keyword) ::
          {:ok, list(binary)} | {:error, :enoent | Jason.DecodeError.t()}
  defp get_resources(api_version, opts) do
    with {:ok, config} <- get_config(opts) do
      resources = Map.get(config, api_version, [])
      {:ok, resources}
    end
  end

  @spec get_config(keyword) :: {:ok, map} | {:error, :enoent | Jason.DecodeError.t()}
  defp get_config(opts) do
    default_opts()
    |> Keyword.merge(opts)
    |> Keyword.get(:config, "")
    |> File.read()
    |> case do
      {:ok, data} -> Jason.decode(data)
      error -> error
    end
  end

  @spec default_opts() :: Keyword.t()
  defp default_opts do
    case K8s.default_discovery_driver() do
      __MODULE__ -> K8s.default_discovery_opts()
      _ -> []
    end
  end
end
