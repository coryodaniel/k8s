# Connections (`K8s.Conn`)

A connection (`K8s.Conn`) is the encapsulation of cluster information and authentication. They can be built using two helper functions (`K8s.Conn.from_file/2`, `K8s.Conn.from_service_account/2`) or by programmatically.

## Building Connections

There are a few helper functions for creating `K8s.Conn`s, but they can also be created by using a struct.

**Using `K8s.Conn.from_env/2`:**

`K8s.Conn.from_env/2` takes an env variable name as binary (defaults to `KUBECONFIG`). Bonny reads its value and forwards the call to `K8s.Conn.from_file/2`.
The options passed as second argument are the same as for `K8s.Conn.from_file/2`.

```elixir
# Reads KUBECONFIG env varable:
{:ok, conn} = K8s.Conn.from_env()
```

To pass the env variable explicitely and specify options:

```elixir
{:ok, conn} = K8s.Conn.from_env("K8S_CONFIG_FILE", insecure_skip_tls_verify: true)
```

**Using `K8s.Conn.from_file/2`:**

`K8s.Conn.from_file/2` accepts a keyword list as the second argument for selecting a `cluster`, `user`, and/or `context` from your kubeconfig file.

```elixir
{:ok, conn} = K8s.Conn.from_file("/path/to/kube/config", context: "your-context-name-here")
```

**Using `K8s.Conn.from_service_account/2`:**

If a path isn't provided for the service account, the default path is used `/var/run/secrets/kubernetes.io/serviceaccount`.

```elixir
{:ok, conn} = K8s.Conn.from_service_account()
```

Optionally the path can be specified:

```elixir
{:ok, conn} = K8s.Conn.from_service_account("/path/to/service/account/directory")
```

**Creating a `K8s.Conn` struct programmatically:**

For the use case of having an unbound number of connections (a multi-tenant K8s service) connections can be manually created.

```elixir
{:ok, cert} = K8s.Conn.PKI.cert_from_map(cluster, base_path)
 %K8s.Conn{
    url: "https://ip-address-of-cluster",
    ca_cert: cert,
    auth: %K8s.Conn.Auth{},
    insecure_skip_tls_verify: false,
    discovery_driver: K8s.Discovery.Driver.HTTP,
    discovery_opts: [cache: true]
  }
```

See [authentication](./authentication.md) and [discovery](./discovery.md) for details on these options.
