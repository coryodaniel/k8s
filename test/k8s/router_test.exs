defmodule K8s.RouterTest do
  use ExUnit.Case
  use ExUnitProperties
  alias K8s.{Operation, Router, Swagger}
  doctest K8s.Router

  @k8s_spec System.get_env("K8S_SPEC") || "priv/swagger/1.13.json"
  @swagger @k8s_spec |> File.read!() |> Jason.decode!()
  @paths @swagger["paths"]
  @swagger_operations @paths
                      |> Enum.reduce([], fn {path, ops}, agg ->
                        operations =
                          ops
                          |> Enum.filter(fn {method, op} ->
                            method != "parameters" &&
                              Map.has_key?(op, "x-kubernetes-group-version-kind") &&
                              op["x-kubernetes-action"] != "connect" &&
                              !Regex.match?(~r/\/watch\//, path) &&
                              !Regex.match?(~r/\/(finalize|bindings|approval|scale)$/, path)
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

  defp expected_path(path) do
    path
    |> String.replace("{namespace}", "foo")
    |> String.replace("{name}", "bar")
    |> String.replace("{path}", "pax")
    |> String.replace("{logpath}", "qux")
  end

  def path_opts(params) when not is_list(params), do: []

  def path_opts(params) when is_list(params) do
    values = [namespace: "foo", name: "bar", path: "pax", logpath: "qux"]

    Enum.reduce(params, [], fn param, agg ->
      case param["in"] do
        "path" ->
          name = String.to_existing_atom(param["name"])
          agg ++ [{name, values[name]}]

        _ ->
          agg
      end
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

  def fn_to_test(:deletecollection, _), do: :delete_collection
  def fn_to_test(action, _), do: action

  property "generates valid paths" do
    check all op <- member_of(@swagger_operations) do
      path = op["path"]
      route_function = op["x-kubernetes-action"]
      params = op["parameters"]

      expected = expected_path(path)

      swagger_operation_action =
        case Swagger.subaction(path) do
          nil -> String.to_atom(route_function)
          subaction -> String.to_atom("#{route_function}_#{subaction}")
        end

      operation_prefix = apply(__MODULE__, :fn_to_test, [swagger_operation_action, op])

      %{"version" => version, "group" => group, "kind" => kind} =
        op["x-kubernetes-group-version-kind"]

      api_version = api_version(group, version)
      opts = path_opts(params)

      operation = Operation.build(operation_prefix, api_version, kind, opts)
      assert expected == Router.path_for(operation, :default)
    end
  end

  describe "start/2" do
    test "starts a named router" do
      router_name = Router.start("priv/swagger/1.10.json", :legacy)
      assert router_name == :legacy
    end
  end
end
