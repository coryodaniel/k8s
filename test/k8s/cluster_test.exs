defmodule K8s.ClusterTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true
  use ExUnitProperties
  doctest K8s.Cluster

  alias K8s.{Operation}
  require Logger

  @k8s_spec System.get_env("K8S_SPEC") || "test/support/swagger/1.14.json"
  @swagger @k8s_spec |> File.read!() |> Jason.decode!()
  @paths @swagger["paths"]
  @unimplemented_subresources ~r/\/(eviction|finalize|bindings|binding|approval|scale|status)$/
  @swagger_operations @paths
                      |> Enum.reduce([], fn {path, ops}, agg ->
                        operations =
                          ops
                          |> Enum.filter(fn {method, op} ->
                            method != "parameters" &&
                              Map.has_key?(op, "x-kubernetes-group-version-kind") &&
                              op["x-kubernetes-action"] != "connect" &&
                              !Regex.match?(~r/\/watch\//, path) &&
                              !Regex.match?(@unimplemented_subresources, path)
                          end)
                          |> Enum.map(fn {method, op} ->
                            path_params = @paths[path]["parameters"] || []
                            op_params = op["parameters"] || []

                            op
                            |> Map.put("http_method", method)
                            |> Map.put("path", path)
                            |> Map.put("parameters", path_params ++ op_params)
                          end)

                        agg ++ operations
                      end)

  setup_all do
    conf = K8s.Conf.from_file("./test/support/kube-config.yaml")
    K8s.Cluster.register(:routing_tests, conf)
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

  def group_version(nil, version), do: version
  def group_version("", version), do: version
  def group_version(group, version), do: "#{group}/#{version}"

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

  property "generates valid paths" do
    check all op <- member_of(@swagger_operations) do
      path = op["path"]
      expected = expected_path(path)

      opts = path_opts(path)
      verb = action_to_verb(op["x-kubernetes-action"], op)
      operation = build_operation(path, verb, opts)

      assert {:ok, url} = K8s.Cluster.url_for(operation, :routing_tests)
      assert String.ends_with?(url, expected)
    end
  end

  @spec build_operation(binary, binary, keyword) :: Operation.t()
  def build_operation(path, verb, opts) do
    [_ | components] = String.split(path, "/")
    {group_version, pluralized_kind_with_subaction} = components_to_operation(components)

    Operation.build(verb, group_version, pluralized_kind_with_subaction, opts)
  end

  # /apis cluster scoped
  def components_to_operation(["apis", group, version, plural_kind]) do
    {group_version(group, version), plural_kind}
  end

  def components_to_operation(["apis", group, version, plural_kind, "{name}"]) do
    {group_version(group, version), plural_kind}
  end

  def components_to_operation(["apis", group, version, plural_kind, "{name}", subaction]) do
    {group_version(group, version), "#{plural_kind}/#{subaction}"}
  end

  # /apis Namespace scoped
  def components_to_operation(["apis", group, version, "namespaces", "{namespace}", plural_kind]) do
    {group_version(group, version), plural_kind}
  end

  def components_to_operation([
        "apis",
        group,
        version,
        "namespaces",
        "{namespace}",
        plural_kind,
        "{name}"
      ]) do
    {group_version(group, version), plural_kind}
  end

  def components_to_operation([
        "apis",
        group,
        version,
        "namespaces",
        "{namespace}",
        plural_kind,
        "{name}",
        subaction
      ]) do
    {group_version(group, version), "#{plural_kind}/#{subaction}"}
  end

  # /api Cluster scoped
  def components_to_operation(["api", version, plural_kind]) do
    {group_version(nil, version), plural_kind}
  end

  def components_to_operation(["api", version, plural_kind, "{name}"]) do
    {group_version(nil, version), plural_kind}
  end

  def components_to_operation(["api", version, plural_kind, "{name}", subaction]) do
    {group_version(nil, version), "#{plural_kind}/#{subaction}"}
  end

  # /api Namespace scoped
  def components_to_operation(["api", version, "namespaces", "{namespace}", plural_kind]) do
    {group_version(nil, version), plural_kind}
  end

  def components_to_operation(["api", version, "namespaces", "{namespace}", plural_kind, "{name}"]) do
    {group_version(nil, version), plural_kind}
  end

  def components_to_operation([
        "api",
        version,
        "namespaces",
        "{namespace}",
        plural_kind,
        "{name}",
        subaction
      ]) do
    {group_version(nil, version), "#{plural_kind}/#{subaction}"}
  end

  def components_to_operation(list) do
    {:error, list}
  end
end
