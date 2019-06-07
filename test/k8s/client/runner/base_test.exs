defmodule K8s.Client.Runner.BaseTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.Base

  alias K8s.Client
  alias K8s.Client.Runner.Base

  setup do
    conf = K8s.Conf.from_file("test/support/kube-config.yaml")
    cluster = K8s.Cluster.register("base-test", conf)

    {:ok, cluster: cluster}
  end

  def namespace_manifest() do
    %{
      "apiVersion" => "v1",
      "metadata" => %{"name" => "test"},
      "kind" => "Namespace"
    }
  end

  describe "run/3" do
    test "running an operation without an HTTP body", %{cluster: cluster} do
      operation = Client.get(namespace_manifest())
      assert {:ok, _} = Base.run(operation, cluster)
    end

    test "running an operation with an HTTP body", %{cluster: cluster} do
      operation = Client.create(namespace_manifest())
      assert {:ok, _} = Base.run(operation, cluster)
    end

    test "running an operation with options", %{cluster: cluster} do
      operation = Client.get(namespace_manifest())
      opts = [params: %{"watch" => "true"}]
      assert {:ok, _} = Base.run(operation, cluster, opts)
    end
  end

  describe "run/4" do
    test "running an operation with a custom HTTP body", %{cluster: cluster} do
      operation = Client.create(namespace_manifest())
      labels = %{"env" => "test"}
      body = put_in(namespace_manifest(), ["metadata", "labels"], labels)

      assert {:ok, _} = Base.run(operation, cluster, body)
    end

    test "running an operation with a custom HTTP body and options", %{
      cluster: cluster
    } do
      operation = Client.create(namespace_manifest())
      labels = %{"env" => "test"}
      body = put_in(namespace_manifest(), ["metadata", "labels"], labels)
      opts = [params: %{"watch" => "true"}]
      assert {:ok, _} = Base.run(operation, cluster, body, opts)
    end
  end

  describe "run" do
    test "request with HTTP 2xx response with no body", %{cluster: cluster} do
      operation = Client.list("v1", "Namespace", [])
      assert {:ok, nil} = Base.run(operation, cluster)
    end
  end
end
