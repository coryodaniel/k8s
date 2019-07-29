defmodule K8s.Cluster.DiscoveryTest do
  use ExUnit.Case, async: true
  alias K8s.Cluster.Discovery

  describe "api_version/1" do
    test "returns a list of API versions" do
      cluster = :test
      file = "test/support/discovery/sample_api_versions.json"
      {:ok, api_versions} = Discovery.api_versions(cluster, path: file)

      assert Enum.member?(api_versions, "v1")
      assert Enum.member?(api_versions, "batch/v1")
    end
  end

  describe "resource_definitions/1" do
    test "returns full resource definitions" do
      cluster = :test
      file = "test/support/discovery/sample_resource_definitions.json"
      {:ok, resource_definitions} = Discovery.resource_definitions(cluster, path: file)

      assert Enum.member?(resource_definitions, %{
               "apiVersion" => "v1",
               "groupVersion" => "batch/v1",
               "kind" => "APIResourceList",
               "resources" => [%{"kind" => "Job", "name" => "jobs"}]
             })

      assert length(resource_definitions) > 1
    end
  end

  describe "resources_by_group/2" do
    test "returns resources group by API version" do
      cluster = :test
      file = "test/support/discovery/sample_resource_definitions.json"
      {:ok, actual} = Discovery.resources_by_group(cluster, path: file)

      assert_lists_equal(actual["batch/v1"], [%{"kind" => "Job", "name" => "jobs"}])
    end

    test "includes subresources" do
      cluster = :test
      file = "test/support/discovery/sample_resource_definitions.json"
      {:ok, actual} = Discovery.resources_by_group(cluster, path: file)
      apps_v1 = actual["apps/v1"]
      core_v1 = actual["v1"]

      assert_lists_equal(apps_v1, [
        %{"kind" => "DaemonSet", "name" => "daemonsets"},
        %{"kind" => "Deployment", "name" => "deployments"},
        %{"kind" => "Deployment", "name" => "deployments/status"}
      ])

      assert_lists_equal(core_v1, [
        %{"kind" => "Namespace", "name" => "namespaces"},
        %{
          "group" => "policy",
          "kind" => "Eviction",
          "name" => "pods/eviction",
          "namespaced" => true,
          "singularName" => "",
          "verbs" => ["create"],
          "version" => "v1beta1"
        },
        %{
          "categories" => ["all"],
          "kind" => "Pod",
          "name" => "pods",
          "namespaced" => true,
          "shortNames" => ["po"],
          "singularName" => "",
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
      ])
    end
  end

  defp assert_lists_equal(list1, list2) do
    assert Enum.sort(list1) == Enum.sort(list2)
  end
end
