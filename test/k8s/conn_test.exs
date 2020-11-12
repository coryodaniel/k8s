defmodule K8s.ConnTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest K8s.Conn
  alias K8s.Conn.Auth.{AuthProvider, Certificate, Exec, Token}
  alias K8s.Conn.RequestOptions

  describe "list/0" do
    test "returns a list of all registered Conns" do
      conns = K8s.Conn.list()
      conn_names = Enum.map(conns, & &1.cluster_name)
      assert conn_names == ["docker-for-desktop-cluster"]
    end
  end

  describe "lookup/1" do
    test "returns a conn by name" do
      assert {:ok, %K8s.Conn{}} = K8s.Conn.lookup("test")
    end

    test "returns an error when no connection was registered" do
      assert {:error, :connection_not_registered} = K8s.Conn.lookup("foo")
    end
  end

  describe "from_file/2" do
    test "returns an error tuple when using an invalid cluster name" do
      assert {:error, :invalid_configuration} =
               K8s.Conn.from_file("test/support/kube-config.yaml",
                 cluster: "this-cluster-does-not-exist"
               )
    end

    test "returns an error tuple when using an invalid user name" do
      assert {:error, :invalid_configuration} =
               K8s.Conn.from_file("test/support/kube-config.yaml",
                 user: "this-user-does-not-exist"
               )
    end

    test "returns an error tuple when using an invalid context name" do
      assert {:error, :invalid_configuration} =
               K8s.Conn.from_file("test/support/kube-config.yaml",
                 context: "this-context-does-not-exist"
               )
    end

    test "parses a configuration file" do
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
      assert %Certificate{} = conn.auth
      assert conn.url == "https://localhost:6443"
      assert conn.cluster_name == "docker-for-desktop-cluster"
      assert conn.user_name == "docker-for-desktop"
    end

    test "using an alternate cluster: cluster-with-cert-data" do
      {:ok, conn} =
        K8s.Conn.from_file("test/support/kube-config.yaml", cluster: "cluster-with-cert-data")

      assert %Certificate{} = conn.auth
      assert conn.url == "https://123.123.123.123"
      assert conn.cluster_name == "cluster-with-cert-data"
      assert conn.ca_cert
      assert conn.auth.certificate
      assert conn.auth.key
    end

    test "using an alternate cluster" do
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", cluster: "cert-cluster")
      assert %Certificate{} = conn.auth
      assert conn.url == "https://localhost:6443"
      assert conn.cluster_name == "cert-cluster"
      assert conn.ca_cert
      assert conn.auth.certificate
      assert conn.auth.key
    end

    test "using an alternate context" do
      {:ok, conn} =
        K8s.Conn.from_file("test/support/kube-config.yaml", context: "insecure-context")

      assert %Certificate{} = conn.auth
      assert conn.url == "https://localhost:6443"
      refute conn.ca_cert
      assert conn.insecure_skip_tls_verify
      assert conn.auth.certificate
      assert conn.auth.key
    end

    test "using an alternate user" do
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", user: "base64-cert-user")
      assert %Certificate{} = conn.auth
      assert conn.url == "https://localhost:6443"
      assert conn.user_name == "base64-cert-user"
      assert conn.auth.certificate
      assert conn.auth.key
    end

    test "loading a token user" do
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", user: "token-user")
      assert %Token{} = conn.auth
      assert conn.url == "https://localhost:6443"
      assert conn.auth.token
    end

    test "loading an auth-provider" do
      {:ok, conn} =
        K8s.Conn.from_file("test/support/kube-config.yaml", user: "auth-provider-user")

      assert %AuthProvider{} = conn.auth
      assert conn.url == "https://localhost:6443"
    end

    test "loading an exec user" do
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", user: "exec-user")
      assert %Exec{} = conn.auth
      assert conn.url == "https://localhost:6443"
    end
  end

  describe "use_service_account/2" do
    test "builds a Conn from a directory of serviceaccount related files" do
      System.put_env("KUBERNETES_SERVICE_HOST", "kewlhost")
      System.put_env("KUBERNETES_SERVICE_PORT", "1337")

      {:ok, conn} = K8s.Conn.from_service_account("test_sa_cluster", "test/support/tls")

      assert %Token{} = conn.auth
      assert conn.cluster_name == "test_sa_cluster"
      assert conn.url == "https://kewlhost:1337"
      assert conn.ca_cert
      assert conn.auth.token
    end
  end

  describe "generating RequestOptions" do
    test "generates headers for the given auth provider" do
      opts = [user: "token-user", cluster: "insecure-cluster"]
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(conn)

      assert [{"Authorization", _bearer_token}] = headers
      assert [verify: :verify_none] = ssl_options
    end

    test "generates ssl_options for the given auth provider" do
      opts = [user: "pem-cert-user", cluster: "insecure-cluster"]
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(conn)

      assert headers == []
      assert [cert: _, key: _, verify: :verify_none] = ssl_options
    end

    test "includes cacerts if provided" do
      opts = [user: "pem-cert-user", cluster: "cert-cluster"]
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(conn)

      assert headers == []
      assert [cert: _, key: _, cacerts: [_cert]] = ssl_options
    end

    test "when skipping TLS verification" do
      opts = [user: "pem-cert-user", cluster: "insecure-cluster"]
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(conn)

      assert headers == []
      assert [cert: _, key: _, verify: :verify_none] = ssl_options
    end
  end
end
