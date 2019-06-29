defmodule K8s.Cluster.PathTest do
  use ExUnit.Case, async: true
  doctest K8s.Cluster.Path

  defp resource_definition() do
    %{
      "kind" => "Pod",
      "name" => "pods",
      "namespaced" => true,
      "verbs" => [
        "create",
        "delete",
        "deletecollection",
        "get",
        "list",
        "patch",
        "update",
        "watch"
      ]
    }
  end

  describe "build/4" do
    test "when a required param is missing, returns an error tuple" do
      res = K8s.Cluster.Path.build("v1", resource_definition(), :update, namespace: "default")
      assert {:error, :missing_required_param, [:name]} = res
    end
  end
end
