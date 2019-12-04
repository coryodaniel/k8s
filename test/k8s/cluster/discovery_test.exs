defmodule K8s.Cluster.DiscoveryTest do
  use ExUnit.Case, async: true
  alias K8s.Cluster.Discovery

  describe "resources_by_group/2" do
    test "returns resources group by API version" do
      cluster = :test
      file = "test/support/discovery/example.json"
      {:ok, resources_by_group} = Discovery.resources_by_group(cluster, config: file)

      core_resources = resources_by_group["v1"]
      core_resource_names = Enum.map(core_resources, & &1["name"])
      core_resource_names_sorted = Enum.sort(core_resource_names)
      assert core_resource_names_sorted == ["namespaces", "pods", "pods/eviction", "services"]
    end

    test "includes subresources" do
      cluster = :test
      file = "test/support/discovery/example.json"
      {:ok, actual} = Discovery.resources_by_group(cluster, config: file)
      core_v1 = actual["v1"]

      assert Enum.member?(core_v1, %{
               "group" => "policy",
               "kind" => "Eviction",
               "name" => "pods/eviction",
               "namespaced" => true,
               "verbs" => ["create"],
               "version" => "v1beta1"
             })
    end
  end

  defp assert_lists_equal(list1, list2) do
    assert Enum.sort(list1) == Enum.sort(list2)
  end
end
