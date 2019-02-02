defmodule K8s.GroupTest do
  use ExUnit.Case, async: true
  doctest K8s.Group

  defp daemonset() do
    %{
      "kind" => "DaemonSet",
      "name" => "daemonsets",
      "namespaced" => true,
      "shortNames" => [
        "ds"
      ]
    }
  end

  defp deployment() do
    %{
      "kind" => "Deployment",
      "name" => "deployments",
      "namespaced" => true,
      "shortNames" => [
        "deploy"
      ]
    }
  end

  defp resources() do
    [daemonset(), deployment()]
  end

  describe "find_resource_by_name/2" do
    test "finds a resource by atom name" do
      {:ok, dep} = K8s.Group.find_resource_by_name(resources(), :deployment)
      assert %{"kind" => "Deployment"} = dep
    end

    test "finds a resource by plural name" do
      {:ok, dep} = K8s.Group.find_resource_by_name(resources(), :deployments)
      assert %{"kind" => "Deployment"} = dep
    end

    test "finds a resource by kind name" do
      {:ok, dep} = K8s.Group.find_resource_by_name(resources(), "Deployment")
      assert %{"kind" => "Deployment"} = dep
    end

    test "returns an error when the resource is not supported" do
      {:error, :unsupported_kind} = K8s.Group.find_resource_by_name(resources(), "Foo")
    end
  end
end
