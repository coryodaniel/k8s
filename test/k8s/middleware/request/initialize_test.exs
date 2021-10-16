defmodule K8s.Middleware.Request.InitializeTest do
  use ExUnit.Case, async: true

  test "initializes a request headers from K8s.Conn.RequestOptions" do
    {:ok, conn} = K8s.Conn.from_file("./test/support/kube-config.yaml")
    request = %K8s.Middleware.Request{conn: conn}

    {:ok, %{headers: headers}} = K8s.Middleware.Request.Initialize.call(request)

    assert headers == [Accept: "application/json"]
  end

  test "initializes a HTTPoison options from K8s.Conn.RequestOptions" do
    {:ok, conn} = K8s.Conn.from_file("./test/support/kube-config.yaml")
    request = %K8s.Middleware.Request{conn: conn}

    {:ok, %{opts: opts}} = K8s.Middleware.Request.Initialize.call(request)

    assert Keyword.has_key?(opts, :ssl)
  end
end
