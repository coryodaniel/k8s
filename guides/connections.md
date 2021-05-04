# Connections (`K8s.Conn`)

A connection (`K8s.Conn`) is the encapsulation of cluster information and authentication. They can be built using two helper functions (`K8s.Conn.from_file/2`, `K8s.Conn.from_service_account/1`) or by programmatically.

## Building Connections

There are a few helper functions for creating `K8s.Conn`s, but they can also be created by using a struct.

**Using `K8s.Conn.from_file/2`:**

`K8s.Conn.from_file/2` accepts a keyword list as the second argument for selecting a `cluster`, `user`, and/or `context` from your kubeconfig file.

```elixir
{:ok, conn} = K8s.Conn.from_file("/path/to/kube/config", context: "your-context-name-here")
```

**Using `K8s.Conn.from_service_account/1`:**

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
 %K8s.Conn{
    url: "https://ip-address-of-cluster",
    ca_cert: K8s.Conn.PKI.cert_from_map(cluster, base_path),
    auth: %K8s.Conn.Auth{},
    insecure_skip_tls_verify: false,
    discovery_driver: K8s.Discovery.Driver.HTTP,
    discovery_opts: [cache: true]
  }
```

See [authentication](./authentication.md) and [discovery](./discovery.md) for details on these options.
