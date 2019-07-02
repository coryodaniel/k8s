defmodule K8s.Cluster.GroupTest do
  use ExUnit.Case, async: true
  doctest K8s.Cluster.Group

  defp daemonset() do
    %{
      "kind" => "DaemonSet",
      "name" => "daemonsets",
      "namespaced" => true
    }
  end

  defp deployment() do
    %{
      "kind" => "Deployment",
      "name" => "deployments",
      "namespaced" => true
    }
  end

  defp deployment_status() do
    %{
      "kind" => "Deployment",
      "name" => "deployments/status",
      "namespaced" => true
    }
  end

  defp resources() do
    [daemonset(), deployment(), deployment_status()]
  end

  describe "find_resource_by_name/2" do
    test "finds a resource by name" do
      {:ok, deployment_status} =
        K8s.Cluster.Group.find_resource_by_name(resources(), "deployments/status")

      assert deployment_status == deployment_status()
    end

    test "finds a resource by atom kind" do
      {:ok, deployment} = K8s.Cluster.Group.find_resource_by_name(resources(), :deployment)
      assert %{"kind" => "Deployment"} = deployment
    end

    test "finds a resource by plural atom kind" do
      {:ok, deployment} = K8s.Cluster.Group.find_resource_by_name(resources(), :deployments)
      assert %{"kind" => "Deployment"} = deployment
    end

    test "finds a resource by string kind" do
      {:ok, deployment} = K8s.Cluster.Group.find_resource_by_name(resources(), "Deployment")
      assert %{"kind" => "Deployment"} = deployment
    end

    test "returns an error when the resource is not supported" do
      {:error, :unsupported_resource, "Foo"} =
        K8s.Cluster.Group.find_resource_by_name(resources(), "Foo")
    end
  end
end
