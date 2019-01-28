defmodule K8s.Cluster do
  @moduledoc """
  Cluster configuration and API route store for `K8s.Client`
  """
  @api_provider Application.get_env(:k8s, :api_provider, K8s.API)

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
    groups = @api_provider.groups(cluster_name)

    Enum.each(groups, fn %{"groupVersion" => gv, "resources" => rs} ->
      cluster_group_key = cluster_group_key(cluster_name, gv)
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
    key = cluster_group_key(cluster_name, group_version)
    conf = K8s.Cluster.conf(cluster_name)

    case :ets.lookup(K8s.Group, key) do
      [] ->
        {:error, :unsupported_group_version, group_version}

      [{_, group_version, resources}] ->
        case find_resource_supporting_verb(resources, kind, verb) do
          {:error, type, details} ->
            {:error, type, details}

          resource ->
            path = K8s.Path.build(group_version, resource, verb, operation.path_params)
            Path.join(conf.url, path)
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

  @spec find_resource_supporting_verb(list(map), binary, atom) ::
          map | {:error, :unsupported_verb, binary}
  defp find_resource_supporting_verb(resources, kind, verb) do
    with {:ok, resource} <- find_resource_by_name(resources, kind),
         true <- resource_supports_verb?(resource, verb) do
      resource
    else
      false ->
        {:error, :unsupported_verb, verb}

      error ->
        error
    end
  end

  def resource_supports_verb?(_, :watch), do: false

  def resource_supports_verb?(%{"verbs" => verbs}, :list_all_namespaces),
    do: Enum.member?(verbs, "list")

  def resource_supports_verb?(%{"verbs" => verbs}, verb),
    do: Enum.member?(verbs, Atom.to_string(verb))

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

  @doc """
  List registered cluster names
  """
  @spec list() :: list(binary | atom)
  def list() do
    K8s.Conf
    |> :ets.tab2list()
    |> Keyword.keys()
  end

  defp cluster_group_key(cluster_name, group_version), do: "#{cluster_name}/#{group_version}"
end
