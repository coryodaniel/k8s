defmodule K8s.Swagger do
  @moduledoc """
  Converts a swagger spec into operation metadata.

  Path params are the params in swagger paths. The combinations are:

  * `{name}`
  * `{namespace}`
  * `{namespace} {name}`
  * `{namespace} {path}`
  * `{name} {path}`
  * `{logpath}`
  """

  @path_params [:name, :namespace, :path, :logpath]
  @doc false
  def path_params, do: @path_params

  @doc """
  Generates route information from a swagger spec file
  """
  @spec build(binary()) :: map()
  def build(file) when is_binary(file) do
    file |> File.read!() |> Jason.decode!() |> build
  end

  @doc """
  Generates route information from a `map` of a parsed swagger spec file. This allows a calling library to generate a swagger spec on its own and provide it to the client.
  """
  @spec build(map) :: map()
  def build(%{"paths" => paths}) when is_map(paths) do
    paths
    |> Enum.reduce(%{}, fn {path, operations}, agg ->
      Map.merge(agg, route_details(operations, path))
    end)
  end

  def build(_), do: %{}

  @doc """
  Map operation metadata to an `K8s.Operation` action name
  """
  @spec gen_action_name(map()) :: binary()
  def gen_action_name(metadata = %{"action" => name}), do: do_gen_action_name(metadata, name)

  @spec do_gen_action_name(map(), binary()) :: binary()
  defp do_gen_action_name(%{"all_namespaces" => true}, name), do: "#{name}_all_namespaces"
  defp do_gen_action_name(_, name), do: name

  @doc """
  Find valid path params in a URL path.

  ## Examples

      iex> K8s.Swagger.find_params("/foo/{name}")
      [:name]

      iex> K8s.Swagger.find_params("/foo/{namespace}/bar/{name}")
      [:namespace, :name]

      iex> K8s.Swagger.find_params("/foo/bar")
      []

  """
  @spec find_params(binary()) :: list(atom())
  def find_params(path_with_args) do
    ~r/{([a-z]+)}/
    |> Regex.scan(path_with_args)
    |> Enum.map(fn match -> match |> List.last() |> String.to_existing_atom() end)
  end

  # Create apiVersion from group and version
  defp api_version("", version), do: version
  defp api_version(group, version), do: "#{group}/#{version}"

  # Build our metadata
  defp metadata(operation, method, path) do
    gvk = operation["x-kubernetes-group-version-kind"]
    group = gvk["group"]
    version = gvk["version"]
    id = operation["operationId"]
    action = operation["x-kubernetes-action"]
    path_params = find_params(path)

    action =
      case subaction(path) do
        nil -> "#{action}"
        subaction -> "#{action}_#{subaction}"
      end

    %{
      "action" => action,
      "path_params" => path_params,
      "id" => id,
      "desc" => operation["description"],
      "api_version" => api_version(group, version),
      "kind" => gvk["kind"],
      "method" => method,
      "path" => path,
      "all_namespaces" => Regex.match?(~r/AllNamespaces$/, id),
      "params" => operation["parameters"]
    }
  end

  @methods ~w(get post delete put patch options head)
  defp route_details(operations, path) do
    for {http_method, operation} <- operations,
        # remove "parameters" from list of HTTP methods
        http_method in @methods,
        # only build paths for things that are have gvk
        Map.has_key?(operation, "x-kubernetes-group-version-kind"),
        # Skip `connect` operations
        operation["x-kubernetes-action"] != "connect",
        # Skip `Scale` resources
        operation["x-kubernetes-group-version-kind"]["kind"] != "Scale",
        # Skip finalize, bindings and approval subactions
        !Regex.match?(~r/\/(finalize|bindings|approval)$/, path),
        # Skip deprecated watch paths; no plan to support
        !Regex.match?(~r/\/watch\//, path),
        into: %{},
        do: {operation["operationId"], metadata(operation, http_method, path)}
  end

  @doc """
  Returns the subaction from a path
  """
  def subaction(path) do
    ~r/\/(log|status)$/
    |> Regex.scan(path)
    |> Enum.map(fn matches -> List.last(matches) end)
    |> List.first()
  end
end
