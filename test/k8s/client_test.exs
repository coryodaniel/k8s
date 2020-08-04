defmodule K8s.ClientTest do
  use ExUnit.Case, async: true
  doctest K8s.Client

  defmodule IntegrationTest do
    use ExUnit.Case, async: false

    def conn() do
      # @HERE HTTP Driver needs to be per connection.
      "KUBECONFIG"
      |> System.get_env()
      |> K8s.Conn.from_file()
    end

    def pod() do
      %{
        "apiVersion" => "v1",
        "kind" => "Pod",
        "metadata" => %{"name" => "nginx-pod", "namespace" => "test"},
        "spec" => %{"containers" => %{"image" => "nginx"}}
      }
    end

    setup do
      {:ok, %{conn: conn()}}
    end

    @tag external: true
    describe "namespaced scoped resources" do
      test "creating a resource", %{conn: conn} do
        op = K8s.Client.create(pod())
        result = K8s.Client.run(op, conn)
        
        assert {:ok, _pod} = result
      end

      test "getting a resource", %{conn: conn} do
        op = K8s.Client.get("v1", "ServiceAccount", name: "default", namespace: "default")
        result = K8s.Client.run(op, conn)
        
        assert {:ok,  %{"apiVersion" => "v1", "kind" => "ServiceAccount"}} = result
      end

      test "listing resources", %{conn: conn} do
        op = K8s.Client.list("v1", "ServiceAccount", namespace: "default")
        {:ok, service_accounts} = K8s.Client.run(op, conn)
        
        assert length(service_accounts) == 1
        assert %{"apiVersion" => "v1", "kind" => "ServiceAccount"} = List.first(service_accounts)
      end
    end

    # @tag external: true
    # describe "cluster scoped resources" do
    #   test "foo", %{conn: conn} do
    #     assert false
    #   end
    # end

    # @tag external: true
    # describe "custom resources" do
    #   test "foo", %{conn: conn} do
    #     assert false
    #   end
    # end
  end
end
