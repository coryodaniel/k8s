defmodule K8s.Cluster do
  @moduledoc """
  Cluster configuration and API route store for `K8s.Client`
  """

  @doc """
  Register a new cluster to use with `K8s.Client`

  ## Examples

      iex> routes = K8s.Router.generate_routes("./test/support/swagger/simple.json")
      ...> conf = K8s.Conf.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.register("test-cluster", routes, conf)
      "test-cluster"

  """
  @spec register(binary, map, K8s.Conf.t()) :: binary
  def register(cluster_name, routes, conf) do
    :ets.insert(K8s.Conf, {cluster_name, conf})

    Enum.each(routes, fn {key, path} ->
      cluster_route_key = cluster_route_key(cluster_name, key)
      :ets.insert(K8s.Router, {cluster_route_key, path, cluster_name, key})
    end)

    cluster_name
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

  @doc false
  def register_clusters do
    clusters = Application.get_env(:k8s, :clusters)

    Enum.each(clusters, fn {name, details} ->
      spec_path = Path.join(:code.priv_dir(:k8s), "swagger/#{details.api_version}.json")
      routes = K8s.Router.generate_routes(spec_path)
      conf = K8s.Conf.from_file(details.conf)

      K8s.Cluster.register(name, routes, conf)
    end)
  end

  @doc """
  Retrieve a cluster's connection configuration.

  ## Example

      iex> routes = K8s.Router.generate_routes("./test/support/swagger/simple.json")
      ...> conf = K8s.Conf.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.register("test-cluster", routes, conf)
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
  Retrieve a cluster's routes

  ## Example

      iex> routes = K8s.Router.generate_routes("./test/support/swagger/simple.json")
      ...> conf = K8s.Conf.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.register("test-cluster", routes, conf)
      ...> K8s.Cluster.routes("test-cluster")
      %{
        "delete/apps/v1/deployment/name/namespace" => ["/apis/apps/v1/namespaces/{namespace}/deployments/{name}"],
        "delete_collection/apps/v1/deployment/namespace" => ["/apis/apps/v1/namespaces/{namespace}/deployments"],
        "get/apps/v1/deployment/name/namespace" => ["/apis/apps/v1/namespaces/{namespace}/deployments/{name}"],
        "list/apps/v1/deployment/namespace" => ["/apis/apps/v1/namespaces/{namespace}/deployments"],
        "patch/apps/v1/deployment/name/namespace" => ["/apis/apps/v1/namespaces/{namespace}/deployments/{name}"],
        "post/apps/v1/deployment/namespace" => ["/apis/apps/v1/namespaces/{namespace}/deployments"],
        "put/apps/v1/deployment/name/namespace" => ["/apis/apps/v1/namespaces/{namespace}/deployments/{name}"]
      }

  """
  def routes(cluster_name) do
    K8s.Router
    |> :ets.match({:_, :"$2", cluster_name, :"$1"})
    |> Enum.reduce(%{}, fn [key | path], agg -> Map.put(agg, key, path) end)
  end

  @doc """
  Retrieve the URL for a `K8s.Operation`

  ## Examples

      iex> routes = K8s.Router.generate_routes("./test/support/swagger/simple.json")
      ...> conf = K8s.Conf.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.register("test-cluster", routes, conf)
      ...> operation = K8s.Operation.build(:get, "apps/v1", :deployment, [namespace: "default", name: "nginx"])
      ...> K8s.Cluster.url_for(operation, "test-cluster")
      "https://localhost:6443/apis/apps/v1/namespaces/default/deployments/nginx"
  """
  @spec url_for(K8s.Operation.t(), binary()) :: binary | nil
  def url_for(operation, cluster_name) do
    conf = conf(cluster_name)

    case path_for(cluster_name, operation.id) do
      nil ->
        nil

      path_template ->
        path = K8s.Router.replace_path_vars(path_template, operation.path_params)
        Path.join(conf.url, path)
    end
  end

  @doc """
  Retrieve the path template for a given cluster and `K8s.Operation` id

  ## Examples

      iex> routes = K8s.Router.generate_routes("./test/support/swagger/simple.json")
      ...> conf = K8s.Conf.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.register("test-cluster", routes, conf)
      ...> K8s.Cluster.path_for("test-cluster", "patch/apps/v1/deployment/name/namespace")
      "/apis/apps/v1/namespaces/{namespace}/deployments/{name}"
  """
  @spec path_for(binary, binary) :: binary | nil
  def path_for(cluster_name, key) do
    cluster_route_key = cluster_route_key(cluster_name, key)

    case :ets.lookup(K8s.Router, cluster_route_key) do
      [] -> nil
      [{_, path, _, _}] -> path
    end
  end

  defp cluster_route_key(cluster_name, key), do: "#{cluster_name}/#{key}"
end
