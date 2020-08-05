defmodule K8s.ClientTest do
  use ExUnit.Case, async: true
  doctest K8s.Client

  defmodule IntegrationTest do
    use ExUnit.Case, async: false

    def conn do
      conn =
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

    describe "namespaced scoped resources" do
      @tag external: true
      test "creating a resource", %{conn: conn, test_id: test_id} do
        pod = pod("nginx-#{test_id}")
        op = K8s.Client.create(pod)
        result = K8s.Client.run(op, conn)

        assert {:ok, _pod} = result
      end

      @tag external: true
      test "getting a resource", %{conn: conn} do
        op = K8s.Client.get("v1", "ServiceAccount", name: "default", namespace: "default")
        result = K8s.Client.run(op, conn)

        assert {:ok, %{"apiVersion" => "v1", "kind" => "ServiceAccount"}} = result
      end

      @tag external: true
      test "listing resources", %{conn: conn} do
        op = K8s.Client.list("v1", "ServiceAccount", namespace: "default")

        assert {:ok,
                %{
                  "items" => service_accounts,
                  "apiVersion" => "v1",
                  "kind" => "ServiceAccountList"
                }} = K8s.Client.run(op, conn)

        assert length(service_accounts) == 1
      end
    end
  end
end
