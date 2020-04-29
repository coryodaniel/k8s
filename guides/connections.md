# Server Connections and Configuration

A connection (`K8s.Conn`) is the encapsulation of cluster information and authentication. They can be registered at compile time, runtime via environment variables, and runtime manually by creating a struct.

`K8s.Conn`s can be registered via Mix Config (`config.exs`) or environment variables. `K8s.Conn`s may also be built programmaticaly. Multiple clusters can be registered via config or at runtime.

See `K8s.Conn.Config`.

## Registering Connections at Compile Time (config.exs)

Connections are _named_ (the key in the `clusters` map below). The name is only important when registering `K8s.Middleware` for specific server connections.

Adding a cluster named `:default` using `~/.kube/config`. Defaults to `current-context` of the kube config file.

```elixir
config :k8s,
  clusters: %{
    default: %{
      conn: "~/.kube/config"
    }
  }
```

Multiple clusters connections can be configured by adding additional keys to the `clusters` map. Connections can later be looked up using `K8s.Conn.lookup/1`. The `lookup/1` function can _only find connections that are registered via a Mix config or environment variables_.

```elixir
{:ok, conn} = K8s.Conn.lookup(:default)
```

Alternatively additional connection options can be specified to use other `context`s, `user`s, and `cluster`s.

**Using a different _context_:**

```elixir
config :k8s,
  clusters: %{
    default: %{
      conn: "~/.kube/config"
      conn_opts: [context: "other-context"]
    }
  }
```

**Setting *cluster* and *user* explicitly:**

```elixir
config :k8s,
  clusters: %{
    default: %{
      conn: "~/.kube/config"
      conn_opts: [user: "some-user", cluster: "prod-cluster"]
    }
  }
```

**Using a pod's service account (`pod.spec.serviceAccountName`):**

A cluster name with a blank configuration will default to using the pod's service account.

```elixir
config :k8s, clusters: %{
  default: %{}
}
```

## Registering Connections with Environment Variables

Multiple clusters can be registered via environment variables. Keep in mind that under the hood, `k8s` uses Kubernetes config files and service account directories.

**Environment Variable Prefixes:**

Prefixes are used to configure multiple connections. The word following the last underscore `_` in the prefix will be the name of the connection. This name _will be atomized_.

* `K8S_CLUSTER_CONF_SA_` - *boolean* enables authentication to the k8s API with the pods `spec.serviceAccount`.
* `K8S_CLUSTER_CONF_PATH_` - *string* absolute path to the kube config file.
* `K8S_CLUSTER_CONF_CONTEXT_` *string* which context to use in the kube config file.

**Examples:**

Configure access to a cluster named `us_central` to use the pod's service account:

```shell
export K8S_CLUSTER_CONF_SA_us_central=true
```

Set the path to a `kubeconfig` file and the context to use for `us_east`:

```shell
export K8S_CLUSTER_CONF_PATH_us_east="east.yaml"
export K8S_CLUSTER_CONF_CONTEXT_us_east="east"
```

Register multiple clusters:

```shell
export K8S_CLUSTER_CONF_SA_us_central=true
export K8S_CLUSTER_CONF_PATH_us_east="east.yaml"
export K8S_CLUSTER_CONF_CONTEXT_us_east="east"
export K8S_CLUSTER_CONF_PATH_us_west="west.yaml"
export K8S_CLUSTER_CONF_CONTEXT_us_west="west"
```

## Building connections programmatically

There are a few helper functions for creating `K8s.Conn`s, but they can also be created by using a struct.

**Using `K8s.Conn.from_file/2`:**

Using a kube config file will set the cluster name to the name of the cluster in the kube config.

```elixir
conn = K8s.Conn.from_file("/path/to/kube/config", context: "docker-for-desktop")
```

**Using `K8s.Conn.from_service_account/2`:**

A cluster name must be provided when creating connections from service account directories.

If a path isn't provided for the service account, the default path is used `/var/run/secrets/kubernetes.io/serviceaccount`.

```elixir
conn = K8s.Conn.from_service_account("cluster_name_here")
```

Optionally the path can be specified:

```elixir
conn = K8s.Conn.from_service_account("cluster_name_here", "/path/to/service/account/directory")
```

**Creating a `K8s.Conn` struct manually:**

For the use case of having an unbound number of connections (a multi-tenant K8s service) connections can be manually created.

```elixir
 %K8s.Conn{
    cluster_name: "default",
    user_name: "optional-user-name-in-kubeconfig",
    url: "https://ip-address-of-cluster",
    ca_cert: K8s.Conn.PKI.cert_from_map(cluster, base_path),
    auth: %K8s.Conn.Auth{},
    insecure_skip_tls_verify: false,
    discovery_driver: K8s.Discovery.Driver.HTTP,
    discovery_opts: [cache: true]
  }
```

See [authentication](./authentication.md) and [discovery](./discovery.md) for details on these options.