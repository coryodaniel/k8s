defmodule K8s.Cluster do
  @moduledoc """
  Cluster configuration and API route store for `K8s.Client`
  """

  alias K8s.{Cluster, Operation}

  @doc """
  Retrieve the URL for a `K8s.Operation`

  ## Examples

      iex> conn = K8s.Conn.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.Registry.add(:test_cluster, conn)
      ...> operation = K8s.Operation.build(:get, "apps/v1", :deployments, [namespace: "default", name: "nginx"])
      ...> K8s.Cluster.url_for(operation, :test_cluster)
      {:ok, "https://localhost:6443/apis/apps/v1/namespaces/default/deployments/nginx"}

  """
  @spec url_for(Operation.t(), atom) :: {:ok, binary} | {:error, atom(), binary()}
  def url_for(%Operation{api_version: api_version, name: name, verb: _verb} = operation, cluster) do
    with {:ok, conn} <- Cluster.conn(cluster),
         {:ok, name} <- Cluster.Group.resource_name_for_kind(cluster, api_version, name),
         operation <- Map.put(operation, :name, name),
         {:ok, path} <- Operation.to_path(operation) do
      {:ok, Path.join(conn.url, path)}
    end
  end

  @doc """
  Retrieve a cluster's connection configuration.

  ## Example

      iex> config_file = K8s.Conn.from_file("./test/support/kube-config.yaml", [user: "token-user"])
      ...> K8s.Cluster.Registry.add(:test_cluster, config_file)
      ...> {:ok, conn} = K8s.Cluster.conn(:test_cluster)
      ...> conn
      %K8s.Conn{auth: %K8s.Conn.Auth.Token{token: "just-a-token-user-pun-intended"}, ca_cert: nil, cluster_name: "docker-for-desktop-cluster", insecure_skip_tls_verify: true, url: "https://localhost:6443",user_name: "token-user", discovery_driver: K8s.Discovery.Driver.File, discovery_opts: [config: "test/support/discovery/example.json"]}
  """
  @spec conn(atom) :: {:ok, K8s.Conn.t()} | {:error, :cluster_not_registered}
  def conn(cluster_name) do
    case :ets.lookup(K8s.Conn, cluster_name) do
      [] -> {:error, :cluster_not_registered}
      [{_, conn}] -> {:ok, conn}
    end
  end

  @doc """
  List registered cluster names
  """
  @spec list() :: list(atom)
  def list() do
    K8s.Conn
    |> :ets.tab2list()
    |> Keyword.keys()
  end
end
