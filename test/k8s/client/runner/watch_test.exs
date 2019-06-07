defmodule K8s.Client.Runner.WatchTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.Watch
  alias K8s.Client.Runner.Watch

  def get_operation() do
    %K8s.Operation{
      method: :get,
      verb: :get,
      group_version: "v1",
      kind: "Pod",
      path_params: [namespace: "test", name: "nginx-pod"]
    }
  end

  def list_operation() do
    %K8s.Operation{
      method: :get,
      verb: :list,
      group_version: "v1",
      kind: "Pod",
      path_params: [namespace: "test"]
    }
  end

  describe "run/4" do
    test "watching a list operation from a specific resource version" do
      operation = K8s.Client.list("v1", "Namespace")
      assert {:ok, _} = Watch.run(operation, :test, 0, stream_to: self())

      assert_receive %HTTPoison.AsyncStatus{code: 200}
      assert_receive %HTTPoison.AsyncHeaders{}
      assert_receive %HTTPoison.AsyncChunk{chunk: "Namespace Watcher"}
      assert_receive %HTTPoison.AsyncEnd{}
    end
  end

  describe "run/3" do
    test "watching a list all operation" do
      operation = K8s.Client.list("v1", "Namespace")
      assert {:ok, _} = Watch.run(operation, :test, stream_to: self())

      assert_receive %HTTPoison.AsyncStatus{code: 200}
      assert_receive %HTTPoison.AsyncHeaders{}
      assert_receive %HTTPoison.AsyncChunk{chunk: "Namespace Watcher"}
      assert_receive %HTTPoison.AsyncEnd{}
    end

    test "watching a get operation" do
      operation = K8s.Client.get("v1", "Namespace", name: "test")
      assert {:ok, _} = Watch.run(operation, :test, stream_to: self())

      assert_receive %HTTPoison.AsyncStatus{code: 200}
      assert_receive %HTTPoison.AsyncHeaders{}
      assert_receive %HTTPoison.AsyncChunk{chunk: "Namespace Watcher"}
      assert_receive %HTTPoison.AsyncEnd{}
    end

    test "returns an error when its not a get or list operation" do
      pod = %{
        "apiVersion" => "apps/v1",
        "kind" => "Deployment",
        "metadata" => %{
          "name" => "nginx",
          "namespace" => "test"
        },
        "spec" => %{
          "containers" => %{
            "image" => "nginx",
            "name" => "nginx"
          }
        }
      }

      operation = K8s.Client.create(pod)
      assert {:error, msg} = Watch.run(operation, :test, stream_to: self())
    end
  end
end
