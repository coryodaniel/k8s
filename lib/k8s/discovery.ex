defmodule K8s.Discovery do
  @moduledoc "Kubernetes API Discovery"
  alias K8s.{Conn, Operation}

  @behaviour K8s.Discovery.Driver

  @impl true
  @doc "Kubernetes API Resources supported by the cluster."
  def resources(api_version, %K8s.Conn{discovery_driver: driver} = conn, opts \\ []) do
    driver.resources(api_version, conn, opts)
  end

  @impl true
  @doc "Kubernetes API Versions supported by the cluster."
  def versions(%K8s.Conn{discovery_driver: driver} = conn, opts \\ []) do
    driver.versions(conn, opts)
  end

  @doc """
  Discovery the URL for a `K8s.Conn` and `K8s.Operation`

  ## Examples

      iex> {:ok, conn} = K8s.Conn.from_file("./test/support/kube-config.yaml")
      ...> op = K8s.Operation.build(:get, "apps/v1", :deployments, [namespace: "default", name: "nginx"])
      ...> K8s.Discovery.url_for(conn, op)
      {:ok, "https://localhost:6443/apis/apps/v1/namespaces/default/deployments/nginx"}

  """
  @spec url_for(Conn.t(), Operation.t()) :: {:ok, String.t()} | {:error, K8s.Discovery.Error.t()}
  def url_for(%Conn{} = conn, %Operation{api_version: api_version, name: name, verb: _} = op) do
    with {:ok, name} <-
           K8s.Discovery.ResourceFinder.resource_name_for_kind(conn, api_version, name),
         op <- Map.put(op, :name, name),
         {:ok, path} <- Operation.to_path(op) do
      {:ok, Path.join(conn.url, path)}
    end
  end

  @spec default_driver() :: module()
  @deprecated "Use K8s.default_discovery_driver/0 instead"
  def default_driver, do: K8s.default_discovery_driver()

  @deprecated "Use K8s.default_discovery_opts/0 instead"
  @spec default_opts() :: Keyword.t()
  def default_opts, do: K8s.default_discovery_opts()
end
