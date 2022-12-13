# Usage

- [Connections (`K8s.Conn`)](./connections.md)
- [Operations (`K8s.Operation`)](./operations.md)
- [Discovery (`K8s.Discovery`)](./discovery.md)
- [Middleware (`K8s.Middleware`)](./middleware.md)
- [Authentication (`K8s.Conn.Auth`)](./authentication.md)
- [Observability](./observability.md)
- [Testing](./testing.md)
- [Advanced Topics](./advanced.md) - CRDs, Multiple Clusters, and Subresource Requests

## tl;dr Examples

### Creating a deployment

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")

opts = [namespace: "default", name: "nginx", image: "nginx:nginx:1.7.9"]
{:ok, resource} = K8s.Resource.from_file("priv/deployment.yaml", opts)

operation = K8s.Client.create(resource)
{:ok, deployment} = K8s.Client.run(conn, operation)
```

### Listing deployments

In a namespace:

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")

operation = K8s.Client.list("apps/v1", "Deployment", namespace: "prod")
{:ok, deployments} = K8s.Client.run(conn, operation)
```

Across all namespaces:

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")

operation = K8s.Client.list("apps/v1", "Deployment", namespace: :all)
{:ok, deployments} = K8s.Client.run(conn, operation)
```

### Getting a deployment

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")

operation = K8s.Client.get("apps/v1", :deployment, [namespace: "default", name: "nginx-deployment"])
{:ok, deployment} = K8s.Client.run(conn, operation)
```
