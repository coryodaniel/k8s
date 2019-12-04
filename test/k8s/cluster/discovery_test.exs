defmodule K8s.Cluster.DiscoveryTest do
  use ExUnit.Case, async: true
  alias K8s.Cluster.Discovery

  describe "resources_by_group/2" do
    test "returns resources group by API version" do
      cluster = :test
      file = "test/support/discovery/example.json"
      {:ok, actual} = Discovery.resources_by_group(cluster, config: file)

      assert_lists_equal(actual["apps/v1"], [
        %{
          "kind" => "DaemonSet",
          "name" => "daemonsets",
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
        },
        %{
          "kind" => "Deployment",
          "name" => "deployments",
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
        },
        %{
          "kind" => "Deployment",
          "name" => "deployments/status",
          "namespaced" => true,
          "verbs" => ["get", "patch", "update"]
        }
      ])
    end

    test "includes subresources" do
      cluster = :test
      file = "test/support/discovery/example.json"
      {:ok, actual} = Discovery.resources_by_group(cluster, config: file)
      core_v1 = actual["v1"]

      assert_lists_equal(core_v1, [
        %{
          "kind" => "Namespace",
          "name" => "namespaces",
          "namespaced" => false,
          "verbs" => ["create", "delete", "get", "list", "patch", "update", "watch"]
        },
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
        },
        %{
          "group" => "policy",
          "kind" => "Eviction",
          "name" => "pods/eviction",
          "namespaced" => true,
          "verbs" => ["create"],
          "version" => "v1beta1"
        }
      ])
    end
  end

  defp assert_lists_equal(list1, list2) do
    assert Enum.sort(list1) == Enum.sort(list2)
  end
end
