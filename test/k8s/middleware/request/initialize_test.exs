defmodule K8s.Middleware.Request.InitializeTest do
  use ExUnit.Case, async: true

  test "initializes a request headers from K8s.Conn.RequestOptions" do
    conn = K8s.Conn.from_file("./test/support/kube-config.yaml")
    K8s.Cluster.Registry.add(:test_cluster, conn)

    request = %K8s.Middleware.Request{cluster: :test_cluster}
    {:ok, %{headers: headers}} = K8s.Middleware.Request.Initialize.call(request)

    assert headers == [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  end

  test "initializes a HTTPoison options from K8s.Conn.RequestOptions" do
    conn = K8s.Conn.from_file("./test/support/kube-config.yaml")
    K8s.Cluster.Registry.add(:test_cluster, conn)

    request = %K8s.Middleware.Request{cluster: :test_cluster}
    {:ok, %{opts: opts}} = K8s.Middleware.Request.Initialize.call(request)

    assert Keyword.has_key?(opts, :ssl)
  end
end
