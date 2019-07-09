defmodule K8s.Cluster.PathTest do
  use ExUnit.Case, async: true
  doctest K8s.Cluster.Path

  describe "build/1" do
    test "when a required param is missing, returns an error" do
      operation = %K8s.Operation{
        method: :get,
        verb: :get,
        data: nil,
        path_params: [namespace: "default"],
        api_version: "v1",
        name: "pods"
      }

      assert {:error, :missing_required_param, [:name]} = K8s.Cluster.Path.build(operation)
    end

    test "given a subresource, when a resource param is missing, returns an error" do
      operation = %K8s.Operation{
        method: :get,
        verb: :get,
        data: nil,
        path_params: [namespace: "default"],
        api_version: "v1",
        name: "pods/status"
      }

      assert {:error, :missing_required_param, [:name]} = K8s.Cluster.Path.build(operation)
    end
  end
end
