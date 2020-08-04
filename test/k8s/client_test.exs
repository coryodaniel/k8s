defmodule K8s.ClientTest do
  use ExUnit.Case, async: true
  doctest K8s.Client

  defmodule IntegrationTest do
    use ExUnit.Case, async: false

    def conn() do
    #   # @HERE HTTP Driver needs to be per connection.
    #   %K8s.Conn{
    #     cluster_name: :default, 
    #     user_name: "optional-user-name-in-kubeconfig",
    #     url: "https://ip-address-of-cluster",
    #     ca_cert: K8s.Conn.PKI.cert_from_map(cluster, base_path),
    #     auth: %K8s.Conn.Auth{},
    #     insecure_skip_tls_verify: false,
    #     discovery_driver: K8s.Discovery.Driver.HTTP,
    #     discovery_opts: [cache: true]
    #   }      
    end

    def pod() do
      %{
        "apiVersion" => "v1",
        "kind" => "Pod",
        "metadata" => %{"name" => "nginx-pod", "namespace" => "test"},
        "spec" => %{"containers" => %{"image" => "nginx"}}
      }
    end

    def setup do
      {:ok, %{conn: conn()}}
    end

    @tag external: true
    describe "namespaced scoped resources" do
      test "creating a resource", %{conn: conn} do
        pod()
        |> K8s.Client.create()
        |> K8s.Client.run(conn)
        assert false
      end
    end

    @tag external: true
    describe "cluster scoped resources" do
      test "foo", %{conn: conn} do
        assert false
      end
    end

    @tag external: true
    describe "custom resources" do
      test "foo", %{conn: conn} do
        assert false
      end
    end
  end
end
