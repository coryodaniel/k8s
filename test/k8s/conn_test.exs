defmodule K8s.ConnTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias K8s.Conn
  alias K8s.Conn.Auth.{Certificate, Token, AuthProvider}
  alias K8s.Conn.RequestOptions

  describe "from_file/2" do
    test "parses a configuration file" do
      config = Conn.from_file("test/support/kube-config.yaml")
      assert %Certificate{} = config.auth
      assert config.url == "https://localhost:6443"
      assert config.cluster_name == "docker-for-desktop-cluster"
      assert config.user_name == "docker-for-desktop"
    end

    test "using an alternate cluster: cluster-with-cert-data" do
      config = Conn.from_file("test/support/kube-config.yaml", cluster: "cluster-with-cert-data")
      assert %Certificate{} = config.auth
      assert config.url == "https://123.123.123.123"
      assert config.cluster_name == "cluster-with-cert-data"
      assert config.ca_cert
      assert config.auth.certificate
      assert config.auth.key
    end

    test "using an alternate cluster" do
      config = Conn.from_file("test/support/kube-config.yaml", cluster: "cert-cluster")
      assert %Certificate{} = config.auth
      assert config.url == "https://localhost:6443"
      assert config.cluster_name == "cert-cluster"
      assert config.ca_cert
      assert config.auth.certificate
      assert config.auth.key
    end

    test "using an alternate context" do
      config = Conn.from_file("test/support/kube-config.yaml", context: "insecure-context")
      assert %Certificate{} = config.auth
      assert config.url == "https://localhost:6443"
      refute config.ca_cert
      assert config.insecure_skip_tls_verify
      assert config.auth.certificate
      assert config.auth.key
    end

    test "using an alternate user" do
      config = Conn.from_file("test/support/kube-config.yaml", user: "base64-cert-user")
      assert %Certificate{} = config.auth
      assert config.url == "https://localhost:6443"
      assert config.user_name == "base64-cert-user"
      assert config.auth.certificate
      assert config.auth.key
    end

    test "loading a token user" do
      config = Conn.from_file("test/support/kube-config.yaml", user: "token-user")
      assert %Token{} = config.auth
      assert config.url == "https://localhost:6443"
      assert config.auth.token
    end

    test "loading an auth-provider" do
      config = Conn.from_file("test/support/kube-config.yaml", user: "auth-provider-user")
      assert %AuthProvider{} = config.auth
      assert config.url == "https://localhost:6443"
    end
  end

  test "use_service_account/0" do
    System.put_env("KUBERNETES_SERVICE_HOST", "kewlhost")
    System.put_env("KUBERNETES_SERVICE_PORT", "1337")

    config = Conn.from_service_account("test/support/tls")
    assert %Token{} = config.auth
    assert config.url == "https://kewlhost:1337"
    assert config.ca_cert
    assert config.auth.token
  end

  describe "generating RequestOptions" do
    test "generates headers for the given auth provider" do
      opts = [user: "token-user", cluster: "insecure-cluster"]
      config = Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(config)

      assert [{"Authorization", bearer_token}] = headers
      assert [verify: :verify_none] = ssl_options
    end

    test "generates ssl_options for the given auth provider" do
      opts = [user: "pem-cert-user", cluster: "insecure-cluster"]
      config = Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(config)

      assert headers == []
      assert [cert: _, key: _, verify: :verify_none] = ssl_options
    end

    test "includes cacerts if provided" do
      opts = [user: "pem-cert-user", cluster: "cert-cluster"]
      config = Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(config)

      assert headers == []
      assert [cert: _, key: _, cacerts: [cert]] = ssl_options
    end

    test "when skipping TLS verification" do
      opts = [user: "pem-cert-user", cluster: "insecure-cluster"]
      config = Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(config)

      assert headers == []
      assert [cert: _, key: _, verify: :verify_none] = ssl_options
    end
  end
end
