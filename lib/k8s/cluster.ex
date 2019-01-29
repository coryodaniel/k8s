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
    groups = @discovery.groups(cluster_name)

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
      "https://localhost:6443/apis/apps/v1/namespaces/default/deployments/nginx"

  """
  @spec url_for(K8s.Operation.t(), binary()) :: binary | nil
  def url_for(operation = %K8s.Operation{}, cluster_name) do
    %{group_version: group_version, kind: kind, verb: verb} = operation
    conf = K8s.Cluster.conf(cluster_name)

    case K8s.Group.find_resource(cluster_name, group_version, kind) do
      {:error, problem, details} ->
        {:error, problem, details}

      {:ok, resource} ->
        case K8s.Path.build(group_version, resource, verb, operation.path_params) do
          {:error, problem, details} -> {:error, problem, details}
          path -> Path.join(conf.url, path)
        end
    end
  end

  @doc """
  Registers clusters automatically from `config.exs`
  """
  def register_clusters do
    clusters = Application.get_env(:k8s, :clusters)

    Enum.each(clusters, fn {name, details} ->
      conf = K8s.Conf.from_file(details.conf)
      K8s.Cluster.register(name, conf)
    end)
  end

  @doc """
  Retrieve a cluster's connection configuration.

  ## Example

      iex> conf = K8s.Conf.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.register("test-cluster", conf)
      ...> K8s.Cluster.conf("test-cluster")
      #Conf<%{cluster: "docker-for-desktop-cluster", user: "docker-for-desktop"}>

  """
  @spec conf(binary) :: K8s.Conf.t() | nil
  def conf(cluster_name) do
    case :ets.lookup(K8s.Conf, cluster_name) do
      [] -> nil
      [{_, conf}] -> conf
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
