defmodule K8s.ClusterTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true
  use ExUnitProperties
  doctest K8s.Cluster

  alias K8s.{Operation}

  @k8s_spec System.get_env("K8S_SPEC") || "test/support/swagger/1.15.json"

  # Create a list of swagger operations to use as input for property tests
  defp swagger_operations() do
    swagger = @k8s_spec |> File.read!() |> Jason.decode!()
    paths = swagger["paths"]

    Enum.reduce(paths, [], fn {path, ops}, agg ->
      operations =
        ops
        |> Enum.filter(fn {method, op} ->
          method != "parameters" &&
            Map.has_key?(op, "x-kubernetes-group-version-kind") &&
            op["x-kubernetes-action"] != "connect" &&
            !Regex.match?(~r/\/watch\//, path)
        end)
        |> Enum.map(fn {method, op} ->
          path_params = paths[path]["parameters"] || []
          op_params = op["parameters"] || []

          op
          |> Map.put("http_method", method)
          |> Map.put("path", path)
          |> Map.put("parameters", path_params ++ op_params)
        end)

      agg ++ operations
    end)
  end

  setup_all do
    conn = K8s.Conn.from_file("./test/support/kube-config.yaml")
    K8s.Cluster.Registry.add(:routing_tests, conn)
    :ok
  end

  defp expected_path(path) do
    path
    |> String.replace("{namespace}", "foo")
    |> String.replace("{name}", "bar")
    |> String.replace("{path}", "pax")
    |> String.replace("{logpath}", "qux")
  end

  def path_opts(path_with_args) do
    values = [namespace: "foo", name: "bar", path: "pax", logpath: "qux"]

    required_params =
      ~r/{([a-z]+)}/
      |> Regex.scan(path_with_args)
      |> Enum.map(fn match -> match |> List.last() |> String.to_existing_atom() end)

    Enum.reduce(required_params, [], fn param, agg ->
      agg ++ [{param, values[param]}]
    end)
  end

  def api_version(nil, version), do: version
  def api_version("", version), do: version
  def api_version(group, version), do: "#{group}/#{version}"

  def fn_to_test(:list, op) do
    case Regex.match?(~r/AllNamespaces/, op["operationId"]) do
      true -> :list_all_namespaces
      false -> :list
    end
  end

  def fn_to_test(verb, _), do: verb

  def action_to_verb(action, op) do
    action = String.to_atom(action)

    mapping = %{
      put: :update,
      post: :create
    }

    mapping
    |> Map.get(action, action)
    |> fn_to_test(op)
  end

  @spec build_operation(binary, binary, keyword) :: Operation.t()
  def build_operation(path, verb, opts) do
    [_ | components] = String.split(path, "/")

    {api_version, pluralized_kind_maybe_with_subresource} = path_segments_to_operation(components)

    Operation.build(verb, api_version, pluralized_kind_maybe_with_subresource, opts)
  end

  # /apis cluster scoped
  def path_segments_to_operation(["apis", group, version, plural_kind]) do
    {api_version(group, version), plural_kind}
  end

  def path_segments_to_operation(["apis", group, version, plural_kind, "{name}"]) do
    {api_version(group, version), plural_kind}
  end

  def path_segments_to_operation(["apis", group, version, plural_kind, "{name}", subresource]) do
    {api_version(group, version), "#{plural_kind}/#{subresource}"}
  end

  # /apis Namespace scoped
  def path_segments_to_operation([
        "apis",
        group,
        version,
        "namespaces",
        "{namespace}",
        plural_kind
      ]) do
    {api_version(group, version), plural_kind}
  end

  def path_segments_to_operation([
        "apis",
        group,
        version,
        "namespaces",
        "{namespace}",
        plural_kind,
        "{name}"
      ]) do
    {api_version(group, version), plural_kind}
  end

  def path_segments_to_operation([
        "apis",
        group,
        version,
        "namespaces",
        "{namespace}",
        plural_kind,
        "{name}",
        subresource
      ]) do
    {api_version(group, version), "#{plural_kind}/#{subresource}"}
  end

  # /api Cluster scoped
  def path_segments_to_operation(["api", version, plural_kind]) do
    {api_version(nil, version), plural_kind}
  end

  def path_segments_to_operation(["api", version, plural_kind, "{name}"]) do
    {api_version(nil, version), plural_kind}
  end

  def path_segments_to_operation(["api", version, plural_kind, "{name}", subresource]) do
    {api_version(nil, version), "#{plural_kind}/#{subresource}"}
  end

  # /api Namespace scoped
  def path_segments_to_operation(["api", version, "namespaces", "{namespace}", plural_kind]) do
    {api_version(nil, version), plural_kind}
  end

  def path_segments_to_operation([
        "api",
        version,
        "namespaces",
        "{namespace}",
        plural_kind,
        "{name}"
      ]) do
    {api_version(nil, version), plural_kind}
  end

  def path_segments_to_operation([
        "api",
        version,
        "namespaces",
        "{namespace}",
        plural_kind,
        "{name}",
        subresource
      ]) do
    {api_version(nil, version), "#{plural_kind}/#{subresource}"}
  end

  def path_segments_to_operation(list) do
    {:error, list}
  end

  # mix test --only debugging
  # Useful for when adding new k8s versions to troubleshooting adding to K8s.Cluster.Group.
  # https://github.com/coryodaniel/k8s/issues/19
  @tag debugging: true
  test "target specific groupVersion/kind" do
    api_version = "v1"
    name = "pods"
    path_params = [namespace: "foo", name: "bar"]
    data = %{}

    operation = %K8s.Operation{
      api_version: api_version,
      name: name,
      method: :patch,
      path_params: path_params,
      data: data,
      verb: :patch
    }

    assert {:ok, url} = K8s.Cluster.url_for(operation, :routing_tests)
  end

  property "generates valid paths" do
    check all(op <- member_of(swagger_operations())) do
      path = op["path"]
      expected = expected_path(path)

      opts = path_opts(path)
      verb = action_to_verb(op["x-kubernetes-action"], op)
      operation = build_operation(path, verb, opts)

      result = K8s.Cluster.url_for(operation, :routing_tests)

      case result do
        {:ok, url} ->
          # File.write!("/tmp/urls.log", "#{url}\n", [:append])
          assert String.ends_with?(url, expected)

        {:error, :unsupported_resource, _resource} ->
          message = "Generated operation: #{inspect(operation)}"
          assert false, message

        error ->
          assert false, "Unhandled operation: #{inspect(error)}"
      end
    end
  end
end
