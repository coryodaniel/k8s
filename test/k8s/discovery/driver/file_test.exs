# credo:disable-for-this-file
defmodule K8s.Discovery.Driver.FileTest do
  use ExUnit.Case, async: true
  alias K8s.Discovery.Driver.File

  @example_config "test/support/discovery/example.json"

  describe "resources/2" do
    test "returns a list of API resources" do
      {:ok, resources} = File.resources("v1", %K8s.Conn{}, config: @example_config)

      resource_names = Enum.map(resources, & &1["name"])
      sorted_resource_names = Enum.sort(resource_names)
      assert sorted_resource_names == ["namespaces", "pods", "pods/eviction", "pods/exec", "services"]
    end
  end

  describe "versions/1" do
    test "returns a list of API versions" do
      {:ok, versions} = File.versions(%K8s.Conn{}, config: @example_config)

      sorted_versions = Enum.sort(versions)
      assert sorted_versions == ["apps/v1", "v1"]
    end
  end
end
