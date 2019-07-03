defmodule K8s.Cluster.PathTest do
  use ExUnit.Case, async: true
  doctest K8s.Cluster.Path

  defp deployment_definition() do
    %{
      "categories" => ["all"],
      "kind" => "Deployment",
      "name" => "deployments",
      "namespaced" => true,
      "shortNames" => ["deploy"],
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
  end

  defp deployment_scale_definition() do
    %{
      "group" => "apps",
      "kind" => "Scale",
      "name" => "deployments/scale",
      "namespaced" => true,
      "singularName" => "",
      "verbs" => ["get", "patch", "update"],
      "version" => "v1beta1"
    }
  end

  defp deployment_status_definition() do
    %{
      "kind" => "Deployment",
      "name" => "deployments/status",
      "namespaced" => true,
      "singularName" => "",
      "verbs" => ["get", "patch", "update"]
    }
  end

  describe "build/4" do
    test "when a required param is missing, returns an error" do
      error = K8s.Cluster.Path.build("v1", deployment_definition(), :update, namespace: "default")
      assert {:error, :missing_required_param, [:name]} = error
    end

    test "given a subresource, when a resource param is missing, returns an error" do
      error =
        K8s.Cluster.Path.build("v1", deployment_scale_definition(), :update, namespace: "default")

      assert {:error, :missing_required_param, [:name]} = error
    end

    test "given a subresource with an alternate kind, returns a path" do
      # i.e.: {"apps/v1", "Scale", "deployments/scale"}
      {:ok, path} =
        K8s.Cluster.Path.build("v1", deployment_scale_definition(), :update,
          namespace: "default",
          name: "foo"
        )

      assert path == "/api/v1/namespaces/default/deployments/foo/scale"
    end

    test "given a subresource with the same kind, returns a path" do
      # i.e.: {"apps/v1", "Deployment", "deployments/status"}
      {:ok, path} =
        K8s.Cluster.Path.build("v1", deployment_status_definition(), :update,
          namespace: "default",
          name: "foo"
        )

      assert path == "/api/v1/namespaces/default/deployments/foo/status"
    end
  end
end
