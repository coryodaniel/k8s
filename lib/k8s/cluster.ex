defmodule K8s.Cluster do
  @moduledoc """
  Cluster configuration and API route store for `K8s.Client`
  """
  @path_params [:name, :namespace, :path, :logpath]
  @api_provider Application.get_env(:k8s, :api_provider, K8s.API)

  @doc """
  Register a new cluster to use with `K8s.Client`

  ## Examples

      iex> conf = K8s.Conf.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.register("test-cluster", conf)
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
            path_template = to_path(group_version, resource, verb)
            required_params = find_params(path_template)
            provided_params = Keyword.keys(operation.path_params)

            case required_params -- provided_params do
              [] ->
                path = K8s.Cluster.replace_path_vars(path_template, operation.path_params)
                Path.join(conf.url, path)
              missing_params ->
                {:error, :missing_required_param, missing_params}
            end
        end
    end
  end

  @spec to_path(binary, map, atom) :: binary
  defp to_path(group_version, %{"namespaced" => ns, "name" => name}, verb) do
    [resource_name | subresource_name] = String.split(name, "/")

    prefix = case String.contains?(group_version, "/") do
      true -> "/apis/#{group_version}"
      false -> "/api/#{group_version}"
    end

    suffix = "#{name_param(resource_name, verb)}/#{subresource_name}"

    build_path(prefix, suffix, ns, verb)
  end

  @spec build_path(binary, binary, boolean, atom) :: binary
  defp build_path(prefix, suffix, true, :list_all_namespaces), do: "#{prefix}/#{suffix}"
  defp build_path(prefix, suffix, true, _), do: "#{prefix}/namespaces/{namespace}/#{suffix}"
  defp build_path(prefix, suffix, false, _), do: "#{prefix}/#{suffix}"

  @spec name_param(binary, atom) :: binary
  defp name_param(resource_name, :create), do: resource_name
  defp name_param(resource_name, :list_all_namespaces), do: resource_name
  defp name_param(resource_name, :list), do: resource_name
  defp name_param(resource_name, :create), do: resource_name
  defp name_param(resource_name, _), do: "#{resource_name}/{name}"

  def find_resource_supporting_verb(resources, kind, verb) do
    with {:ok, resource} <- find_resource_by_name(resources, kind),
         true <- resource_supports_verb?(resource, verb) do
      resource
    else
      false -> {:error, :unsupported_verb, verb}
      error -> error
    end
  end

  def resource_supports_verb?(_, :watch), do: false
  def resource_supports_verb?(%{"verbs" => verbs}, :list_all_namespace),
    do: Enum.member?(verbs, "list")

  def resource_supports_verb?(%{"verbs" => verbs}, verb), do: Enum.member?(verbs, Atom.to_string(verb))

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

  @doc false
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

  defp cluster_group_key(cluster_name, group_version), do: "#{cluster_name}/#{group_version}"

  @doc false
  def path_params, do: @path_params

  @doc """
  Replaces path variables with options.

  ## Examples

      iex> K8s.Cluster.replace_path_vars("/foo/{name}", name: "bar")
      "/foo/bar"

  """
  @spec replace_path_vars(binary(), keyword(atom())) :: binary()
  def replace_path_vars(path_template, opts) do
    Regex.replace(~r/\{(\w+?)\}/, path_template, fn _, var ->
      opts[String.to_existing_atom(var)]
    end)
  end

  @doc """
  Find valid path params in a URL path.

  ## Examples

      iex> K8s.Cluster.find_params("/foo/{name}")
      [:name]

      iex> K8s.Cluster.find_params("/foo/{namespace}/bar/{name}")
      [:namespace, :name]

      iex> K8s.Cluster.find_params("/foo/bar")
      []

  """
  @spec find_params(binary()) :: list(atom())
  def find_params(path_with_args) do
    ~r/{([a-z]+)}/
    |> Regex.scan(path_with_args)
    |> Enum.map(fn match -> match |> List.last() |> String.to_existing_atom() end)
  end
end
