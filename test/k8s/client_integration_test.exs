defmodule K8s.ClientIntegrationTest do
  use ExUnit.Case, async: false

  @spec conn() :: K8s.Conn.t()
  def conn do
    {:ok, conn} =
      "TEST_KUBECONFIG"
      |> System.get_env()
      |> K8s.Conn.from_file()

    # Override the defaults for testing
    %K8s.Conn{
      conn
      | discovery_driver: K8s.Discovery.Driver.HTTP,
        discovery_opts: [],
        http_provider: K8s.Client.HTTPProvider
    }
  end

  @spec pod(String.t()) :: Map.t()
  def pod(name) do
    %{
      "apiVersion" => "v1",
      "kind" => "Pod",
      "metadata" => %{"name" => name, "namespace" => "default"},
      "spec" => %{"containers" => [%{"image" => "nginx", "name" => "nginx"}]}
    }
  end

  setup do
    test_id = :rand.uniform(10_000)
    {:ok, %{conn: conn(), test_id: test_id}}
  end

  describe "cluster scoped resources" do
    @tag external: true
    test "creating a resource", %{conn: conn, test_id: test_id} do
      namespace = %{
        "apiVersion" => "v1",
        "kind" => "Namespace",
        "metadata" => %{"name" => "k8s-ex-#{test_id}"}
      }

      operation = K8s.Client.create(namespace)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result

      operation = K8s.Client.delete(namespace)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result
    end

    @tag external: true
    test "getting a resource", %{conn: conn} do
      operation = K8s.Client.get("v1", "Namespace", name: "default")
      result = K8s.Client.run(conn, operation)

      assert {:ok, %{"apiVersion" => "v1", "kind" => "Namespace"}} = result
    end

    @tag external: true
    test "listing resources", %{conn: conn} do
      operation = K8s.Client.list("v1", "Namespace")

      assert {:ok,
              %{
                "items" => namespaces,
                "apiVersion" => "v1",
                "kind" => "NamespaceList"
              }} = K8s.Client.run(conn, operation)

      namespace_names = Enum.map(namespaces, fn ns -> get_in(ns, ["metadata", "name"]) end)
      assert Enum.member?(namespace_names, "default")
    end
  end

  describe "namespaced scoped resources" do
    @tag external: true
    test "creating a resource", %{conn: conn, test_id: test_id} do
      pod = pod("k8s-ex-#{test_id}")
      operation = K8s.Client.create(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result

      operation = K8s.Client.delete(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result
    end

    @tag external: true
    test "getting a resource", %{conn: conn} do
      operation = K8s.Client.get("v1", "ServiceAccount", name: "default", namespace: "default")
      result = K8s.Client.run(conn, operation)

      assert {:ok, %{"apiVersion" => "v1", "kind" => "ServiceAccount"}} = result
    end

    @tag external: true
    test "listing resources", %{conn: conn} do
      operation = K8s.Client.list("v1", "ServiceAccount", namespace: "default")

      assert {:ok,
              %{
                "items" => service_accounts,
                "apiVersion" => "v1",
                "kind" => "ServiceAccountList"
              }} = K8s.Client.run(conn, operation)

      assert length(service_accounts) == 1
    end
  end
end
