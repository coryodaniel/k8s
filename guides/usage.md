# Usage

- [Connections (`K8s.Conn`)](./connections.md)
- [Operations (`K8s.Operation`)](./operations.md)
- [Discovery (`K8s.Discovery`)](./discovery.md)
- [Middleware (`K8s.Middleware`)](./middleware.md)
- [Authentication (`K8s.Conn.Auth`)](./authentication.md)
- [Observability](./observability.md)
- [Testing](./testing.md)
- [Advanced Topics](./advanced.md) - CRDs, Multiple Clusters, and Subresource Requests
- [Migrations](./migrations.md) - Migrating from earlier versions

## tl;dr Examples

### Creating a deployment

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")

opts = [namespace: "default", name: "nginx", image: "nginx:nginx:1.7.9"]
{:ok, resource} = K8s.Resource.from_file("priv/deployment.yaml", opts)

{:ok, deployment} =
    resource
    |> K8s.Client.create()
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run()
```

### Listing deployments

In a namespace:

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")

{:ok, deployments} =
    K8s.Client.list("apps/v1", "Deployment", namespace: "prod")
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run()
```

Across all namespaces:

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")

{:ok, deployments} =
    K8s.Client.list("apps/v1", "Deployment", namespace: :all)
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run()
```

### Getting a deployment

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")

{:ok, deployment} =
    K8s.Client.get("apps/v1", :deployment, [namespace: "default", name: "nginx-deployment"])
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run(conn, operation)
```
