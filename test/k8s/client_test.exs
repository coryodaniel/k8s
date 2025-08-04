defmodule K8s.ClientTest do
  use ExUnit.Case, async: true
  doctest K8s.Client

  test "generateName with create/1" do
    job = %{
      "apiVersion" => "batch/v1",
      "kind" => "Job",
      "metadata" => %{
        "namespace" => "default",
        "generateName" => "hello-"
      },
      "spec" => %{
        "template" => %{
          "spec" => %{
            "containers" => [
              %{
                "name" => "hello",
                "image" => "busybox",
                "args" => ["/bin/sh", "-c", "echo Hello, world"]
              }
            ],
            "restartPolicy" => "OnFailure"
          }
        }
      }
    }

    assert %K8s.Operation{
             api_version: "batch/v1",
             data: ^job,
             method: :post,
             name: "Job",
             path_params: [namespace: "default"],
             query_params: [],
             verb: :create
           } = K8s.Client.create(job)
  end

  test "generateName with create/1 for cluster scoped resources" do
    ns = %{
      "apiVersion" => "v1",
      "kind" => "Namespace",
      "metadata" => %{
        "generateName" => "hello-"
      }
    }

    assert %K8s.Operation{
             api_version: "v1",
             data: ^ns,
             method: :post,
             name: "Namespace",
             path_params: [],
             query_params: [],
             verb: :create
           } = K8s.Client.create(ns)
  end

  test "generate metrics for Node" do
    assert %K8s.Operation{
        method: :get,
        verb: :metrics,
        api_version: "v1",
        name: "Node",
        data: nil,
        conn: nil,
        path_params: [],
        query_params: [],
        header_params: ["Content-Type": "application/json"]
      } = K8s.Client.metrics("v1", "Node")
  end

  test "generate metrics for Pod" do
    assert %K8s.Operation{
        method: :get,
        verb: :metrics,
        api_version: "v1",
        name: "Pod",
        data: nil,
        conn: nil,
        path_params: [{:namespace, "production"}],
        query_params: [],
        header_params: ["Content-Type": "application/json"]
      } = K8s.Client.metrics("v1", "Pod", namespace: "production")
  end
end
