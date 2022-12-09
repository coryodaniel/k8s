# credo:disable-for-this-file
defmodule K8s.Client.Runner.BaseTest do
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.Base

  alias K8s.Client
  alias K8s.Client.Runner.Base
  alias K8s.Client.DynamicHTTPProvider
  import K8s.Test.IntegrationHelper

  defmodule HTTPMock do
    @namespaced_path "/api/v1/namespaces"

    def request(:get, %URI{path: @namespaced_path}, _, _, _), do: {:ok, nil}

    def request(:post, %URI{path: @namespaced_path}, body, _, _) do
      {:ok, body}
    end

    def request(:get, %URI{path: @namespaced_path <> "/test"}, _body, _headers, _opts) do
      {:ok, nil}
    end

    def request(:get, %URI{path: @namespaced_path <> "/test-query-params"}, _body, _headers, opts) do
      params = Keyword.get(opts, :params)
      {:ok, params}
    end

    def request(
          :get,
          %URI{path: "/apis/apps/v1/namespaces/default/deployments/nginx/status"},
          _body,
          _headers,
          _opts
        ) do
      {:ok, nil}
    end

    def request(
          :get,
          %URI{path: "/api/v1/pods", query: "labelSelector=app%3Dnginx"},
          _body,
          _headers,
          ssl: _ssl
        ) do
      {:ok, nil}
    end

    def request(
          :get,
          %URI{path: "/api/v1/pods", query: "fieldSelector=status.phase%3DRunning"},
          _body,
          _headers,
          ssl: _ssl
        ) do
      {:ok, nil}
    end

    def request(
          :post,
          %URI{path: "/api/v1/namespaces/default/pods/nginx/eviction"},
          body,
          _headers,
          _opts
        ) do
      {:ok, body}
    end

    def request(
          :post,
          %URI{path: "/api/v1/namespaces/default/pods/nginx/exec"},
          _body,
          _headers,
          _opts
        ) do
      {:ok, nil}
    end
  end

  setup do
    DynamicHTTPProvider.register(self(), __MODULE__.HTTPMock)
    {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")

    {:ok, conn: conn}
  end

  describe "run/2" do
    test "running an operation with a label K8s.Selector set", %{conn: conn} do
      operation =
        Client.list("v1", :pods)
        |> K8s.Selector.label({"app", "nginx"})

      assert {:ok, _} = Base.run(conn, operation)
    end

    test "returns an error for watch operations", %{conn: conn} do
      operation = Client.watch("v1", :pods)

      assert {:error, error} = Base.run(conn, operation)
      assert error.message =~ "Use K8s.Client.stream/N"
    end

    test "running an operation with a field K8s.Selector set", %{conn: conn} do
      operation =
        Client.list("v1", :pods)
        |> K8s.Selector.field({"status.phase", "Running"})

      assert {:ok, _} = Base.run(conn, operation)
    end

    test "running an operation without an HTTP body", %{conn: conn} do
      operation = Client.get(build_namespace("test"))
      assert {:ok, _} = Base.run(conn, operation)
    end

    test "running an operation with an HTTP body", %{conn: conn} do
      operation = Client.create(build_namespace("test"))
      assert {:ok, _} = Base.run(conn, operation)
    end

    test "running an operation with options", %{conn: conn} do
      operation = Client.get(build_namespace("test-query-params"))
      operation_w_params = K8s.Operation.put_query_param(operation, :watch, true)

      # TODO: this should assert that the params were actually added
      assert {:ok, _} = Base.run(conn, operation_w_params)
    end

    test "supports subresource operations", %{conn: conn} do
      operation = Client.get("apps/v1", "deployments/status", name: "nginx", namespace: "default")
      assert {:ok, _} = Base.run(conn, operation)
    end
  end

  describe "run/3" do
    test "passes http_opts to the HTTP Provider", %{conn: conn} do
      operation = Client.create(build_namespace("http-opts"))

      assert {:ok, body} = Base.run(conn, operation, stream_to: self())

      # TODO: this should assert that the opts were actually received
      assert body ==
               ~s({"apiVersion":"v1","kind":"Namespace","metadata":{"name":"http-opts"}})
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
