defmodule K8s.ConnTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest K8s.Conn
  alias K8s.Conn.Auth.ServiceAccount
  alias K8s.Conn.Auth.{AuthProvider, Certificate, Exec, Token}
  alias K8s.Conn.RequestOptions

  describe "from_file/2" do
    test "returns an error tuple when using an invalid cluster name" do
      assert {:error, %K8s.Conn.Error{}} =
               K8s.Conn.from_file("test/support/kube-config.yaml",
                 cluster: "this-cluster-does-not-exist"
               )
    end

    test "returns an error tuple when using an invalid user name" do
      assert {:error, %K8s.Conn.Error{}} =
               K8s.Conn.from_file("test/support/kube-config.yaml",
                 user: "this-user-does-not-exist"
               )
    end

    test "returns an error tuple when using an invalid context name" do
      assert {:error, %K8s.Conn.Error{}} =
               K8s.Conn.from_file("test/support/kube-config.yaml",
                 context: "this-context-does-not-exist"
               )
    end

    test "parses a configuration file" do
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
      assert %Certificate{} = conn.auth
      assert conn.url == "https://localhost:6443"
      assert conn.cluster_name == "k8s-elixir-client-cluster"
      assert conn.user_name == "k8s-elixir-client"
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

    test "using an alternate discovery_driver" do
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
      assert K8s.Discovery.Driver.File = conn.discovery_driver

      {:ok, conn} =
        K8s.Conn.from_file("test/support/kube-config.yaml",
          discovery_driver: K8s.Discovery.Driver.HTTP
        )

      assert K8s.Discovery.Driver.HTTP = conn.discovery_driver
    end

    test "using an alternate http_provider" do
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
      assert K8s.Client.DynamicHTTPProvider = conn.http_provider

      {:ok, conn} =
        K8s.Conn.from_file("test/support/kube-config.yaml",
          http_provider: K8s.Client.MintHTTPProvider
        )

      assert K8s.Client.MintHTTPProvider = conn.http_provider
    end

    test "using alternate discovery_opts" do
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
      assert [config: "test/support/discovery/example.json"] = conn.discovery_opts

      {:ok, conn} =
        K8s.Conn.from_file("test/support/kube-config.yaml",
          discovery_opts: :foo
        )

      assert :foo = conn.discovery_opts
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

  describe "from_string/2" do
    setup do
      config_yaml = File.read!("test/support/kube-config-string.yaml")
      {:ok, config_yaml: config_yaml}
    end

    test "returns an error tuple when using an invalid cluster name", %{config_yaml: config_yaml} do
      assert {:error, %K8s.Conn.Error{}} =
               K8s.Conn.from_string(config_yaml, cluster: "this-cluster-does-not-exist")
    end

    test "returns an error tuple when using an invalid user name", %{config_yaml: config_yaml} do
      assert {:error, %K8s.Conn.Error{}} =
               K8s.Conn.from_string(config_yaml, user: "this-user-does-not-exist")
    end

    test "returns an error tuple when using an invalid context name", %{config_yaml: config_yaml} do
      assert {:error, %K8s.Conn.Error{}} =
               K8s.Conn.from_string(config_yaml, context: "this-context-does-not-exist")
    end

    test "parses a configuration string", %{config_yaml: config_yaml} do
      {:ok, conn} = K8s.Conn.from_string(config_yaml)
      assert %Certificate{} = conn.auth
      assert conn.url == "https://localhost:6443"
      assert conn.cluster_name == "string-test-cluster"
      assert conn.user_name == "string-test-user"
      assert conn.ca_cert
      assert conn.auth.certificate
      assert conn.auth.key
    end

    test "using an alternate cluster", %{config_yaml: config_yaml} do
      {:ok, conn} = K8s.Conn.from_string(config_yaml, cluster: "insecure-string-cluster")
      assert conn.url == "https://localhost:6443"
      assert conn.cluster_name == "insecure-string-cluster"
      refute conn.ca_cert
    end

    test "using an alternate context", %{config_yaml: config_yaml} do
      {:ok, conn} = K8s.Conn.from_string(config_yaml, context: "insecure-string-context")
      assert %Token{} = conn.auth
      assert conn.url == "https://localhost:6443"
      assert conn.user_name == "token-string-user"
      assert conn.auth.token == "string-test-token-value"
      assert conn.insecure_skip_tls_verify
    end

    test "using an alternate user", %{config_yaml: config_yaml} do
      {:ok, conn} = K8s.Conn.from_string(config_yaml, user: "token-string-user")
      assert %Token{} = conn.auth
      assert conn.url == "https://localhost:6443"
      assert conn.user_name == "token-string-user"
      assert conn.auth.token == "string-test-token-value"
    end

    test "using an alternate discovery_driver", %{config_yaml: config_yaml} do
      {:ok, conn} = K8s.Conn.from_string(config_yaml)
      assert K8s.Discovery.Driver.File = conn.discovery_driver

      {:ok, conn} =
        K8s.Conn.from_string(config_yaml, discovery_driver: K8s.Discovery.Driver.HTTP)

      assert K8s.Discovery.Driver.HTTP = conn.discovery_driver
    end

    test "using an alternate http_provider", %{config_yaml: config_yaml} do
      {:ok, conn} = K8s.Conn.from_string(config_yaml)
      assert K8s.Client.DynamicHTTPProvider = conn.http_provider

      {:ok, conn} =
        K8s.Conn.from_string(config_yaml, http_provider: K8s.Client.MintHTTPProvider)

      assert K8s.Client.MintHTTPProvider = conn.http_provider
    end

    test "using alternate discovery_opts", %{config_yaml: config_yaml} do
      {:ok, conn} = K8s.Conn.from_string(config_yaml)
      assert [config: "test/support/discovery/example.json"] = conn.discovery_opts

      {:ok, conn} = K8s.Conn.from_string(config_yaml, discovery_opts: :foo)
      assert :foo = conn.discovery_opts
    end

    test "returns error when config contains file path references" do
      config_with_file_paths = """
      apiVersion: v1
      clusters:
      - cluster:
          certificate-authority: /path/to/ca.crt
          server: https://localhost:6443
        name: file-path-cluster
      users:
      - name: file-path-user
        user:
          client-certificate: /path/to/cert.pem
          client-key: /path/to/key.pem
      contexts:
      - context:
          cluster: file-path-cluster
          user: file-path-user
        name: file-path-context
      current-context: file-path-context
      """

      assert {:error, %K8s.Conn.Error{message: message}} =
               K8s.Conn.from_string(config_with_file_paths)

      assert message =~ "File path references (certificate-authority) are not supported"
    end

    test "returns error for invalid YAML" do
      invalid_yaml = "invalid: yaml: content: ["

      assert {:error, _error} = K8s.Conn.from_string(invalid_yaml)
    end
  end

  describe "from_service_account/2" do
    test "builds a Conn from a directory of serviceaccount related files" do
      System.put_env("KUBERNETES_SERVICE_HOST", "kewlhost")
      System.put_env("KUBERNETES_SERVICE_PORT", "1337")

      {:ok, conn} = K8s.Conn.from_service_account("test/support/tls")

      assert %ServiceAccount{} = conn.auth
      assert conn.cluster_name == nil
      assert conn.url == "https://kewlhost:1337"
      assert conn.ca_cert
      assert conn.namespace == "imanamespace"
    end
  end

  describe "from_env/2" do
    test "returns error if env var does not exist" do
      assert {:error, error} = K8s.Conn.from_env("NON_EXISTENT")
      assert Exception.message(error) =~ "not declared"
    end
  end

  describe "generating RequestOptions" do
    test "generates headers for the given auth provider" do
      opts = [user: "token-user", cluster: "insecure-cluster"]
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(conn)

      assert [Authorization: _bearer_token] = headers
      assert [verify: :verify_none, cacertfile: ~c"/etc/ssl/cert.pem"] = ssl_options
    end

    test "generates ssl_options for the given auth provider" do
      opts = [user: "pem-cert-user", cluster: "insecure-cluster"]
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(conn)

      assert headers == []

      assert [verify: :verify_none, cacertfile: ~c"/etc/ssl/cert.pem"] =
               ssl_options
    end

    test "includes cacerts if provided" do
      opts = [user: "pem-cert-user", cluster: "cert-cluster"]
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(conn)

      assert headers == []
      assert [verify: :verify_peer, cacerts: [_cert]] = ssl_options
    end

    test "when skipping TLS verification" do
      opts = [user: "pem-cert-user", cluster: "insecure-cluster"]
      {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml", opts)

      assert {:ok, %RequestOptions{headers: headers, ssl_options: ssl_options}} =
               RequestOptions.generate(conn)

      assert headers == []

      assert [verify: :verify_none, cacertfile: ~c"/etc/ssl/cert.pem"] =
               ssl_options
    end
  end
end
