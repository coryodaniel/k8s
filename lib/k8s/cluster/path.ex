defmodule K8s.Cluster.Path do
  @moduledoc """
  Generates Kubernetes REST API Paths
  """

  @path_params [:namespace, :name, :path, :logpath]

  @doc false
  @spec path_params() :: list(atom)
  def path_params, do: @path_params

  @doc """
  Generates the API path for a given group/version and resource.

  ## Examples

  Generate a path for a cluster scoped resource:

      iex> resource = %{
      ...>   "kind" => "CertificateSigningRequest",
      ...>   "name" => "certificatesigningrequests",
      ...>   "namespaced" => false,
      ...>   "verbs" => ["update"]
      ...> }
      ...> K8s.Cluster.Path.build("apps/v1", resource, :update, [name: "foo"])
      {:ok, "/apis/apps/v1/certificatesigningrequests/foo"}

  Generate a path for a namespace scoped resource:

      iex> resource = %{
      ...>   "kind" => "Pod",
      ...>   "name" => "pods",
      ...>   "namespaced" => true,
      ...>   "verbs" => ["update"]
      ...> }
      ...> K8s.Cluster.Path.build("v1", resource, :update, [namespace: "default", name: "foo"])
      {:ok, "/api/v1/namespaces/default/pods/foo"}

  Generate a path for a namespace scoped resource on the collection: (ie create, list)

      iex> resource = %{
      ...>   "kind" => "Pod",
      ...>   "name" => "pods",
      ...>   "namespaced" => true,
      ...>   "verbs" => ["create"]
      ...> }
      ...> K8s.Cluster.Path.build("v1", resource, :create, [namespace: "default"])
      {:ok, "/api/v1/namespaces/default/pods"}

  Generating a listing path for a namespace:

      iex> resource = %{
      ...>   "kind" => "Pod",
      ...>   "name" => "pods",
      ...>   "namespaced" => true,
      ...>   "verbs" => ["list"]
      ...> }
      ...> K8s.Cluster.Path.build("v1", resource, :list, [namespace: "default"])
      {:ok, "/api/v1/namespaces/default/pods"}

  Generating a listing path for a all namespaces:

      iex> resource = %{
      ...>   "kind" => "Pod",
      ...>   "name" => "pods",
      ...>   "namespaced" => true,
      ...>   "verbs" => ["list"]
      ...> }
      ...> K8s.Cluster.Path.build("v1", resource, :list_all_namespaces, [])
      {:ok, "/api/v1/pods"}

  Generating a path for a subresource:

      iex> resource = %{
      ...>   "kind" => "Pod",
      ...>   "name" => "pods/status",
      ...>   "namespaced" => true,
      ...>   "verbs" => ["get"]
      ...> }
      ...> K8s.Cluster.Path.build("v1", resource, :get, [namespace: "default", name: "foo"])
      {:ok, "/api/v1/namespaces/default/pods/foo/status"}

  Deleting a collection:

      iex> resource = %{
      ...>   "kind" => "Pod",
      ...>   "name" => "pods",
      ...>   "namespaced" => true,
      ...>   "verbs" => [
      ...>     "deletecollection"
      ...>   ]
      ...> }
      ...> K8s.Cluster.Path.build("v1", resource, :deletecollection, [namespace: "default"])
      {:ok, "/api/v1/namespaces/default/pods"}

  """
  @spec build(binary, map, atom, keyword(atom)) ::
          {:ok, binary}
          | {:error, :unsupported_verb}
          | {:error, :missing_required_param, list(atom)}
  def build(api_version, resource, verb, params) do
    case resource_supports_verb?(resource, verb) do
      true ->
        path_template = to_path(api_version, resource, verb)
        required_params = K8s.Cluster.Path.find_params(path_template)
        provided_params = Keyword.keys(params)

        case required_params -- provided_params do
          [] ->
            {:ok, replace_path_vars(path_template, params)}

          missing_params ->
            {:error, :missing_required_param, missing_params}
        end

      false ->
        {:error, :unsupported_verb}
    end
  end

  @doc """
  Replaces path variables with options.

  ## Examples

      iex> K8s.Cluster.Path.replace_path_vars("/foo/{name}", name: "bar")
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

      iex> K8s.Cluster.Path.find_params("/foo/{name}")
      [:name]

      iex> K8s.Cluster.Path.find_params("/foo/{namespace}/bar/{name}")
      [:namespace, :name]

      iex> K8s.Cluster.Path.find_params("/foo/bar")
      []

  """
  @spec find_params(binary()) :: list(atom())
  def find_params(path_with_args) do
    ~r/{([a-z]+)}/
    |> Regex.scan(path_with_args)
    |> Enum.map(fn match -> match |> List.last() |> String.to_existing_atom() end)
  end

  @spec to_path(binary, map, atom) :: binary
  defp to_path(api_version, %{"namespaced" => ns, "name" => name}, verb) do
    prefix =
      case String.contains?(api_version, "/") do
        true -> "/apis/#{api_version}"
        false -> "/api/#{api_version}"
      end

    suffix =
      name
      |> String.split("/")
      |> resource_path_suffix(verb)

    build_path(prefix, suffix, ns, verb)
  end

  defp resource_path_suffix([name], verb), do: name_param(name, verb)

  defp resource_path_suffix([name, subresource], verb),
    do: name_with_subresource_param(name, subresource, verb)

  @spec name_param(binary, atom) :: binary
  defp name_param(resource_name, :create), do: resource_name
  defp name_param(resource_name, :list_all_namespaces), do: resource_name
  defp name_param(resource_name, :list), do: resource_name
  defp name_param(resource_name, :deletecollection), do: resource_name
  defp name_param(resource_name, _), do: "#{resource_name}/{name}"

  @spec name_with_subresource_param(binary, binary, atom) :: binary
  defp name_with_subresource_param(resource_name, subresource, _),
    do: "#{resource_name}/{name}/#{subresource}"

  @spec build_path(binary, binary, boolean, atom) :: binary
  defp build_path(prefix, suffix, true, :list_all_namespaces), do: "#{prefix}/#{suffix}"
  defp build_path(prefix, suffix, true, _), do: "#{prefix}/namespaces/{namespace}/#{suffix}"
  defp build_path(prefix, suffix, false, _), do: "#{prefix}/#{suffix}"

  @spec resource_supports_verb?(map, atom) :: boolean
  defp resource_supports_verb?(_, :watch), do: false

  defp resource_supports_verb?(%{"verbs" => verbs}, :list_all_namespaces),
    do: Enum.member?(verbs, "list")

  defp resource_supports_verb?(%{"verbs" => verbs}, verb),
    do: Enum.member?(verbs, Atom.to_string(verb))
end
