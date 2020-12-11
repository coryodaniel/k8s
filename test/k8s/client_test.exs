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
             label_selector: nil,
             method: :post,
             name: "Job",
             path_params: [namespace: "default"],
             query_params: %{},
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
             label_selector: nil,
             method: :post,
             name: "Namespace",
             path_params: [],
             query_params: %{},
             verb: :create
           } = K8s.Client.create(ns)
  end
end
