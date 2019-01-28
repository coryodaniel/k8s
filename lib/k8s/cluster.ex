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

  def path_for2(cluster_name, group_version, kind, verb) do
    # Note: verb is kubernetes verb (action, elsewhere in code), not HTTP verb (method)
    # TODO: consider adding a cache here
    case :ets.lookup(K8s.Group, "#{cluster_name}/#{group_version}") do
      [] -> {:error, :unsupported_group_version, group_version}
      [{_, group_version, url, resources}] ->
        case find_resource_supporting_verb(resources, kind, verb) do
          {:error, type, details} -> {:error, type, details}
          resource -> Path.join(url, to_path(resource, verb))
        end
    end
  end

  def to_path({:error, _, _} = err, verb), do: err

  def to_path(%{"namespaced" => ns, "name" => name}, verb) do
    [resource_name | subresource_name] = String.split(name, "/")

    path_components = [
      namespace_param(ns, verb),
      name_param(resource_name, verb),
      subresource_name
    ]

    Enum.join(path_components, "/")
  end

  def namespace_param(true, "list_all"), do: ""
  def namespace_param(true, _), do: "namespaces/{namespace}"
  def namespace_param(false, _), do: ""

  def name_param(resource_name, "list"), do: resource_name
  def name_param(resource_name, "list_all"), do: resource_name
  def name_param(resource_name, "create"), do: resource_name
  def name_param(resource_name, _), do: "#{resource_name}/{name}"

  def find_resource_supporting_verb(resources, kind, verb) do
    with {:ok, resource} <- find_resource_by_name(resources, kind),
         true <- resource_supports_verb?(resource, verb) do
      resource
    else
      false -> {:error, :unsupported_verb, verb}
      error -> error
    end
  end

  def resource_supports_verb?(_, "watch"), do: false
  def resource_supports_verb?(%{"verbs" => verbs}, "list_all"), do: Enum.member?(verbs, "list")
  def resource_supports_verb?(%{"verbs" => verbs}, verb), do: Enum.member?(verbs, verb)

  def find_resource_by_name(resources, kind) do
    resource = Enum.find(resources, &match_resource_by_name(&1, kind))

    case resource do
      nil -> {:error, :unsupported_kind, kind}
      resource -> {:ok, resource}
    end
  end

  @spec match_resource_by_name(map, atom | binary) :: bool
  def match_resource_by_name(resource, kind) when is_atom(kind),
    do: match_resource_by_name(resource, Atom.to_string(kind))

  def match_resource_by_name(%{"kind" => kind}, kind), do: true
  def match_resource_by_name(%{"name" => name}, name), do: true
  def match_resource_by_name(%{"kind" => kind}, name), do: String.downcase(kind) == name

  def register2(cluster_name, conf) do
    :ets.insert(K8s.Conf, {cluster_name, conf})
    groups = K8s.API.groups(cluster_name)

    Enum.each(groups, fn %{"groupVersion" => gv, "resources" => rs, "url" => url} ->
      cluster_group_version_key = "#{cluster_name}/#{gv}"
      :ets.insert(K8s.Group, {cluster_group_version_key, gv, url, rs})
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
      spec_path = Path.join(:code.priv_dir(:k8s), "swagger/#{details.group_version}.json")
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
        "deletecollection/apps/v1/deployment/namespace" => ["/apis/apps/v1/namespaces/{namespace}/deployments"],
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
