defmodule K8s.Operation.Path do
  @moduledoc "Generates Kubernetes REST API Paths"
  alias K8s.Operation.Error
  @path_params [:namespace, :name, :path, :logpath]

  @doc false
  @spec path_params() :: list(atom)
  def path_params, do: @path_params

  @doc """
  Generates the API path for a `K8s.Operation`.

  ## Examples

  Generate a path for a cluster scoped resource:

      iex> resource = K8s.Resource.build("apps/v1", "CertificateSigningRequest", "foo")
      ...> operation = %K8s.Operation{
      ...>  method: :put,
      ...>  verb: :update,
      ...>  data: resource,
      ...>  path_params: [name: "foo"],
      ...>  api_version: "apps/v1",
      ...>  name: "certificatesigningrequests"
      ...> }
      ...> K8s.Operation.Path.build(operation)
      {:ok, "/apis/apps/v1/certificatesigningrequests/foo"}


      iex> resource = K8s.Resource.build("apps/v1", "CertificateSigningRequest", "foo")
      ...> operation = %K8s.Operation{
      ...>  method: :put,
      ...>  verb: :update,
      ...>  data: resource,
      ...>  path_params: [name: "foo", namespace: nil],
      ...>  api_version: "apps/v1",
      ...>  name: "certificatesigningrequests"
      ...> }
      ...> K8s.Operation.Path.build(operation)
      {:ok, "/apis/apps/v1/certificatesigningrequests/foo"}

  Generate a path for a namespace scoped resource:

      iex> resource = K8s.Resource.build("v1", "Pod", "default", "foo")
      ...> operation = %K8s.Operation{
      ...>  method: :put,
      ...>  verb: :update,
      ...>  data: resource,
      ...>  path_params: [namespace: "default", name: "foo"],
      ...>  api_version: "v1",
      ...>  name: "pods"
      ...> }
      ...> K8s.Operation.Path.build(operation)
      {:ok, "/api/v1/namespaces/default/pods/foo"}

  Generate a path for a namespace scoped resource on the collection: (ie create, list)

      iex> resource = K8s.Resource.build("v1", "Pod", "default", "foo")
      ...> operation = %K8s.Operation{
      ...>  method: :post,
      ...>  verb: :create,
      ...>  data: resource,
      ...>  path_params: [namespace: "default", name: "foo"],
      ...>  api_version: "v1",
      ...>  name: "pods"
      ...> }
      ...> K8s.Operation.Path.build(operation)
      {:ok, "/api/v1/namespaces/default/pods"}

  Generating a listing path for a namespace:

      iex> operation = %K8s.Operation{
      ...>  method: :get,
      ...>  verb: :list,
      ...>  data: nil,
      ...>  path_params: [namespace: "default"],
      ...>  api_version: "v1",
      ...>  name: "pods"
      ...> }
      ...> K8s.Operation.Path.build(operation)
      {:ok, "/api/v1/namespaces/default/pods"}

  Generating a listing path for a all namespaces:

      iex> operation = %K8s.Operation{
      ...>  method: :get,
      ...>  verb: :list_all_namespaces,
      ...>  data: nil,
      ...>  path_params: [namespace: "default"],
      ...>  api_version: "v1",
      ...>  name: "pods"
      ...> }
      ...> K8s.Operation.Path.build(operation)
      {:ok, "/api/v1/pods"}

  Generating a listing path for a watching all namespaces:

      iex> operation = %K8s.Operation{
      ...>  method: :get,
      ...>  verb: :watch_all_namespaces,
      ...>  data: nil,
      ...>  path_params: [namespace: "default"],
      ...>  api_version: "v1",
      ...>  name: "pods"
      ...> }
      ...> K8s.Operation.Path.build(operation)
      {:ok, "/api/v1/pods"}

  Generating a path for a subresource:

      iex> operation = %K8s.Operation{
      ...>  method: :get,
      ...>  verb: :get,
      ...>  data: nil,
      ...>  path_params: [namespace: "default", name: "foo"],
      ...>  api_version: "v1",
      ...>  name: "pods/status"
      ...> }
      ...> K8s.Operation.Path.build(operation)
      {:ok, "/api/v1/namespaces/default/pods/foo/status"}

  Deleting a collection:

      iex> operation = %K8s.Operation{
      ...>  method: :delete,
      ...>  verb: :deletecollection,
      ...>  data: nil,
      ...>  path_params: [namespace: "default"],
      ...>  api_version: "v1",
      ...>  name: "pods"
      ...> }
      ...> K8s.Operation.Path.build(operation)
      {:ok, "/api/v1/namespaces/default/pods"}
  """
  @spec build(K8s.Operation.t()) :: {:ok, binary} | {:error, Error.t()}
  def build(%K8s.Operation{} = operation) do
    path_template = to_path(operation)
    required_params = K8s.Operation.Path.find_params(path_template)
    provided_params = Keyword.keys(operation.path_params)

    case required_params -- provided_params do
      [] ->
        {:ok, replace_path_vars(path_template, operation.path_params)}

      missing_params ->
        msg = "Missing required params: #{inspect(missing_params)}"
        {:error, %Error{message: msg}}
    end
  end

  @doc """
  Replaces path variables with options.

  ## Examples

      iex> K8s.Operation.Path.replace_path_vars("/foo/{name}", name: "bar")
      "/foo/bar"

  """
  @spec replace_path_vars(binary(), keyword()) :: binary()
  def replace_path_vars(path_template, opts) do
    Regex.replace(~r/\{(\w+?)\}/, path_template, fn _, var ->
      opts[String.to_existing_atom(var)]
    end)
  end

  @doc """
  Find valid path params in a URL path.

  ## Examples

      iex> K8s.Operation.Path.find_params("/foo/{name}")
      [:name]

      iex> K8s.Operation.Path.find_params("/foo/{namespace}/bar/{name}")
      [:namespace, :name]

      iex> K8s.Operation.Path.find_params("/foo/bar")
      []

  """
  @spec find_params(binary()) :: list(atom())
  def find_params(path_with_args) do
    ~r/{([a-z]+)}/
    |> Regex.scan(path_with_args)
    |> Enum.map(fn match -> match |> List.last() |> String.to_existing_atom() end)
  end

  @spec to_path(K8s.Operation.t()) :: binary
  defp to_path(%K8s.Operation{path_params: params} = operation) do
    has_namespace = !is_nil(params[:namespace])
    namespaced = has_namespace && params[:namespace] != :all

    prefix =
      case String.contains?(operation.api_version, "/") do
        true -> "/apis/#{operation.api_version}"
        false -> "/api/#{operation.api_version}"
      end

    suffix =
      operation.name
      |> String.split("/")
      |> resource_path_suffix(operation.verb)

    build_path(prefix, suffix, namespaced, operation.verb)
  end

  @spec resource_path_suffix(list(binary), atom) :: binary
  defp resource_path_suffix([name], verb), do: name_param(name, verb)

  defp resource_path_suffix([name, subresource], verb),
    do: name_with_subresource_param(name, subresource, verb)

  @spec name_param(binary, atom) :: binary
  defp name_param(resource_name, :create), do: resource_name
  defp name_param(resource_name, :list_all_namespaces), do: resource_name
  defp name_param(resource_name, :list), do: resource_name
  defp name_param(resource_name, :deletecollection), do: resource_name
  defp name_param(resource_name, :watch_all_namespaces), do: resource_name
  defp name_param(resource_name, _), do: "#{resource_name}/{name}"

  @spec name_with_subresource_param(binary, binary, atom) :: binary
  defp name_with_subresource_param(resource_name, subresource, _),
    do: "#{resource_name}/{name}/#{subresource}"

  @spec build_path(binary, binary, boolean, atom) :: binary
  defp build_path(prefix, suffix, true, :watch_all_namespaces), do: "#{prefix}/#{suffix}"
  defp build_path(prefix, suffix, true, :list_all_namespaces), do: "#{prefix}/#{suffix}"
  defp build_path(prefix, suffix, true, _), do: "#{prefix}/namespaces/{namespace}/#{suffix}"
  defp build_path(prefix, suffix, false, _), do: "#{prefix}/#{suffix}"
end
