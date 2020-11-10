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

    def request(:get, @namespaced_url <> "/test-query-params", _body, _headers, opts) do
      params = Keyword.get(opts, :params)
      render(params)
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

    {:ok, conn: conn}
  end

  describe "run/3" do
    test "running an operation with a K8s.Selector set", %{conn: conn} do
      operation =
        Client.list("v1", :pods)
        |> K8s.Selector.label({"app", "nginx"})

      assert {:ok, _} = Base.run(conn, operation)
    end

    test "running an operation without an HTTP body", %{conn: conn} do
      operation = Client.get(make_namespace("test"))
      assert {:ok, _} = Base.run(conn, operation)
    end

    test "running an operation with an HTTP body", %{conn: conn} do
      operation = Client.create(make_namespace("test"))
      assert {:ok, _} = Base.run(conn, operation)
    end

    test "running an operation with options", %{conn: conn} do
      operation = Client.get(make_namespace("test-query-params"))
      params = %{"watch" => "true"}
      operation_w_params = Map.put(operation, :query_params, params)

      assert {:ok, ^params} = Base.run(conn, operation_w_params)
    end

    test "supports subresource operations", %{conn: conn} do
      operation = Client.get("apps/v1", "deployments/status", name: "nginx", namespace: "default")
      assert {:ok, _} = Base.run(conn, operation)
    end

    test "running an operation with a custom HTTP body", %{conn: conn} do
      operation = Client.create(make_namespace("test"))
      labels = %{"env" => "test"}
      body = put_in(make_namespace("test"), ["metadata", "labels"], labels)

      assert {:ok, body} = Base.run(conn, operation, body)

      assert body ==
               ~s({"apiVersion":"v1","kind":"Namespace","metadata":{"labels":{"env":"test"},"name":"test"}})
    end
  end

  describe "run/4" do
    test "[DEPRECATED] running an operation with a custom HTTP body and options", %{
      conn: conn
    } do
      operation = Client.create(make_namespace("test"))
      labels = %{"env" => "test"}
      body = put_in(make_namespace("test"), ["metadata", "labels"], labels)

      opts = [params: %{"watch" => "true"}]
      assert {:ok, _} = Base.run(conn, operation, body, opts)
    end
  end

  describe "run" do
    test "request with HTTP 2xx response", %{conn: conn} do
      operation = Client.list("v1", "Namespace", [])
      assert {:ok, _} = Base.run(conn, operation)
    end

    test "supports subresource operations with alternate `kind` HTTP bodies", %{conn: conn} do
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
      assert {:ok, _} = Base.run(conn, operation)
    end
  end
end
