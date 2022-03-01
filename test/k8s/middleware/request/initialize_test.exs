defmodule K8s.Middleware.Request.InitializeTest do
  use ExUnit.Case, async: true

  test "initializes a request headers from K8s.Conn.RequestOptions" do
    {:ok, conn} = K8s.Conn.from_file("./test/support/kube-config.yaml")
    request = %K8s.Middleware.Request{conn: conn, headers: ["Content-Type": "application/json"]}

    {:ok, %{headers: headers}} = K8s.Middleware.Request.Initialize.call(request)

    assert headers == ["Content-Type": "application/json", Accept: "application/json"]
  end

  test "initializes a HTTPoison options from K8s.Conn.RequestOptions" do
    {:ok, conn} = K8s.Conn.from_file("./test/support/kube-config.yaml")
    request = %K8s.Middleware.Request{conn: conn}

    {:ok, %{opts: opts}} = K8s.Middleware.Request.Initialize.call(request)

    assert Keyword.has_key?(opts, :ssl)
  end

  test "initializes a request headers from K8s.Conn.RequestOptions with Authorization token" do
    {:ok, conn} = K8s.Conn.from_file("./test/support/kube-config.yaml", user: "token-user")
    request = %K8s.Middleware.Request{conn: conn, headers: ["Header-Name": "some value"]}

    {:ok, %{headers: headers}} = K8s.Middleware.Request.Initialize.call(request)

    assert Keyword.has_key?(headers, :Authorization)
  end
end
