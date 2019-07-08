defmodule K8s.Cluster.DiscoveryTest do
  use ExUnit.Case, async: true
  alias K8s.Cluster.Discovery

  # describe "resource_identifiers_by_group/2" do
  #   test "" do
  #     assert false
  #   end
  # end

  # describe "api_versions_for_resource/2" do
  #   test "returns a list of API versions" do
  #     cluster = :test
  #     file = "test/support/discovery/sample_api_versions.json"

  #     {:ok, api_versions} =
  #       K8s.Cluster.Discovery.api_versions_for_resource(cluster, "Deployment", path: file)

  #     assert api_versions == ["apps/v1"]
  #   end
  # end

  describe "api_version/1" do
    test "returns a list of API versions" do
      cluster = :test
      file = "test/support/discovery/sample_api_versions.json"
      {:ok, api_versions} = Discovery.api_versions(cluster, path: file)

      assert Enum.member?(api_versions, "v1")
      assert Enum.member?(api_versions, "batch/v1")
    end
  end

  describe "resource_identifiers/1" do
    test "returns a list of resource identifiers" do
      cluster = :test
      file = "test/support/discovery/sample_resource_definitions.json"
      {:ok, resource_identifiers} = Discovery.resource_identifiers(cluster, path: file)

      assert resource_identifiers == [
               {"batch/v1", "Job", "jobs"},
               {"apps/v1", "DaemonSet", "daemonsets"},
               {"apps/v1", "Deployment", "deployments"},
               {"apps/v1", "Deployment", "deployments/status"},
               {"v1", "Namespace", "namespaces"},
               {"v1", "Pod", "pods"},
               {"policy/v1beta1", "Eviction", "pods/eviction"}
             ]
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
    test "returns resources group by groupVersion/apiVersion" do
      cluster = :test
      file = "test/support/discovery/sample_resource_definitions.json"
      {:ok, actual} = Discovery.resources_by_group(cluster, path: file)

      assert_lists_equal(actual["batch/v1"], [%{"kind" => "Job", "name" => "jobs"}])

      assert_lists_equal(actual["apps/v1"], [
        %{"kind" => "DaemonSet", "name" => "daemonsets"},
        %{"kind" => "Deployment", "name" => "deployments"},
        %{"kind" => "Deployment", "name" => "deployments/status"}
      ])
    end

    test "does not include subresources in their parent groupVersion" do
      cluster = :test
      file = "test/support/discovery/sample_resource_definitions.json"
      {:ok, actual} = Discovery.resources_by_group(cluster, path: file)

      assert_lists_equal(actual["v1"], [
        %{"kind" => "Namespace", "name" => "namespaces"},
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

    test "groups subresources by _their_ groupVersion" do
      cluster = :test
      file = "test/support/discovery/sample_resource_definitions.json"
      {:ok, actual} = Discovery.resources_by_group(cluster, path: file)

      assert_lists_equal(actual["policy/v1beta1"], [
        %{
          "group" => "policy",
          "kind" => "Eviction",
          "name" => "pods/eviction",
          "namespaced" => true,
          "singularName" => "",
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
