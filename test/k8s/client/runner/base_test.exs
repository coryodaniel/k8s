# credo:disable-for-this-file
defmodule K8s.Client.Runner.BaseTest do
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.Base

  alias K8s.Client
  alias K8s.Client.Runner.Base
  alias K8s.Client.DynamicHTTPProvider
  import K8s.Test.KubeHelper

  defmodule HTTPMock do
    @base_url "https://localhost:6443"
    @namespaced_url @base_url <> "/api/v1/namespaces"
    import K8s.Test.HTTPHelper

    def request(:get, @namespaced_url, _, _, _), do: render(nil)

    def request(:post, @namespaced_url, body, _, _), do: render(body)

    def request(:get, @namespaced_url <> "/test", _body, _headers, _opts) do
      render(nil)
    end

    def request(
          :get,
          @base_url <> "/apis/apps/v1/namespaces/default/deployments/nginx/status",
          _body,
          _headers,
          _opts
        ) do
      render(nil)
    end

    def request(
          :get,
          @base_url <> "/api/v1/pods",
          _body,
          _headers,
          ssl: _ssl,
          params: %{labelSelector: "app=nginx"}
        ) do
      render(nil)
    end

    def request(
          :post,
          @base_url <> "/api/v1/namespaces/default/pods/nginx/eviction",
          body,
          _headers,
          _opts
        ) do
      render(body)
    end
  end

  setup do
    DynamicHTTPProvider.register(self(), __MODULE__.HTTPMock)
    conn = K8s.Conn.from_file("test/support/kube-config.yaml")
    {:ok, cluster} = K8s.Cluster.Registry.add(:base_runner_test, conn)

    {:ok, cluster: cluster}
  end

  describe "run/3" do
    test "running an operation with a K8s.Selector set", %{cluster: cluster} do
      operation =
        Client.list("v1", :pods)
        |> K8s.Selector.label({"app", "nginx"})

      assert {:ok, _} = Base.run(operation, cluster)
    end

    test "running an operation without an HTTP body", %{cluster: cluster} do
      operation = Client.get(make_namespace("test"))
      assert {:ok, _} = Base.run(operation, cluster)
    end

    test "running an operation with an HTTP body", %{cluster: cluster} do
      operation = Client.create(make_namespace("test"))
      assert {:ok, _} = Base.run(operation, cluster)
    end

    test "running an operation with options", %{cluster: cluster} do
      operation = Client.get(make_namespace("test"))
      opts = [params: %{"watch" => "true"}]
      assert {:ok, _} = Base.run(operation, cluster, opts)
    end

    test "supports subresource operations", %{cluster: cluster} do
      operation = Client.get("apps/v1", "deployments/status", name: "nginx", namespace: "default")
      assert {:ok, _} = Base.run(operation, cluster)
    end
  end

  describe "run/4" do
    test "running an operation with a custom HTTP body", %{cluster: cluster} do
      operation = Client.create(make_namespace("test"))
      labels = %{"env" => "test"}
      body = put_in(make_namespace("test"), ["metadata", "labels"], labels)

      assert {:ok, body} = Base.run(operation, cluster, body)

      assert body ==
               ~s({"apiVersion":"v1","kind":"Namespace","metadata":{"labels":{"env":"test"},"name":"test"}})
    end

    test "running an operation with a custom HTTP body and options", %{
      cluster: cluster
    } do
      operation = Client.create(make_namespace("test"))
      labels = %{"env" => "test"}
      body = put_in(make_namespace("test"), ["metadata", "labels"], labels)
      opts = [params: %{"watch" => "true"}]
      assert {:ok, _} = Base.run(operation, cluster, body, opts)
    end
  end

  describe "run" do
    test "request with HTTP 2xx response", %{cluster: cluster} do
      operation = Client.list("v1", "Namespace", [])
      assert {:ok, _} = Base.run(operation, cluster)
    end

    test "supports subresource operations with alternate `kind` HTTP bodies", %{cluster: cluster} do
      pod = %{
        "apiVersion" => "v1",
        "kind" => "Pod",
        "metadata" => %{
          "name" => "nginx",
          "namespace" => "default"
        }
      }

      eviction = %{
        "apiVersion" => "policy/v1beta1",
        "kind" => "Eviction",
        "metadata" => %{
          "name" => "nginx",
          "namespace" => "default"
        }
      }

      operation = K8s.Client.create(pod, eviction)
      assert {:ok, _} = Base.run(operation, cluster)
    end
  end
end
