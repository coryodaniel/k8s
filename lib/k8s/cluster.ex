defmodule K8s.Cluster do
  @moduledoc """
  Cluster configuration and API route store for `K8s.Client`
  """

  @discovery Application.get_env(:k8s, :discovery_provider, K8s.Discovery)

  @doc """
  Register a new cluster to use with `K8s.Client`

  ## Examples

      iex> conf = K8s.Conf.from_file("./test/support/kube-config.yaml")
      ...> "test-cluster" = K8s.Cluster.register("test-cluster", conf)
      "test-cluster"

  """
  @spec register(binary, K8s.Conf.t()) :: binary
  def register(cluster_name, conf) do
    :ets.insert(K8s.Conf, {cluster_name, conf})
    groups = @discovery.resource_definitions_by_group(cluster_name)

    Enum.each(groups, fn %{"groupVersion" => gv, "resources" => rs} ->
      cluster_group_key = K8s.Group.cluster_key(cluster_name, gv)
      :ets.insert(K8s.Group, {cluster_group_key, gv, rs})
    end)

    cluster_name
  end

  @doc """
  Retrieve the URL for a `K8s.Operation`

  ## Examples

      iex> conf = K8s.Conf.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.register("test-cluster", conf)
      ...> operation = K8s.Operation.build(:get, "apps/v1", :deployment, [namespace: "default", name: "nginx"])
      ...> K8s.Cluster.url_for(operation, "test-cluster")
      {:ok, "https://localhost:6443/apis/apps/v1/namespaces/default/deployments/nginx"}

  """
  @spec url_for(K8s.Operation.t(), binary()) :: {:ok, binary} | {:error, atom} | {:error, binary}
  def url_for(operation = %K8s.Operation{}, cluster_name) do
    %{group_version: group_version, kind: kind, verb: verb} = operation
    {:ok, conf} = K8s.Cluster.conf(cluster_name)

    with {:ok, resource} <- K8s.Group.find_resource(cluster_name, group_version, kind),
         {:ok, path} <- K8s.Path.build(group_version, resource, verb, operation.path_params) do
      {:ok, Path.join(conf.url, path)}
    else
      error -> error
    end
  end

  @doc """
  Registers clusters automatically from `config.exs`

  ## Examples

  By default a cluster will attempt to use the ServiceAccount assigned to the pod:

  ```elixir
  config :k8s,
    clusters: %{
      default: %{}
    }
  ```

  Configuring a cluster using a k8s config:

  ```elixir
  config :k8s,
    clusters: %{
      default: %{
        conf: "~/.kube/config"
        conf_opts: [user: "some-user", cluster: "prod-cluster"]
      }
    }
  ```
  """
  def register_clusters do
    clusters = Application.get_env(:k8s, :clusters, [])

    Enum.each(clusters, fn {name, details} ->
      conf =
        case Map.get(details, :conf) do
          nil ->
            K8s.Conf.from_service_account()

          conf_path ->
            opts = details[:conf_opts] || []
            K8s.Conf.from_file(conf_path, opts)
        end

      K8s.Cluster.register(name, conf)
    end)
  end

  @doc """
  Retrieve a cluster's connection configuration.

  ## Example

      iex> config_file = K8s.Conf.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.register("test-cluster", config_file)
      ...> {:ok, conf} = K8s.Cluster.conf("test-cluster")
      ...> conf
      #Conf<%{cluster: "docker-for-desktop-cluster", user: "docker-for-desktop"}>

  """
  @spec conf(binary) :: {:ok, K8s.Conf.t()} | {:error, :cluster_not_registered}
  def conf(cluster_name) do
    case :ets.lookup(K8s.Conf, cluster_name) do
      [] -> {:error, :cluster_not_registered}
      [{_, conf}] -> {:ok, conf}
    end
  end

  @doc """
  List registered cluster names
  """
  @spec list() :: list(binary | atom)
  def list() do
    K8s.Conf
    |> :ets.tab2list()
    |> Keyword.keys()
  end
end
