# Usage

* [Connections (`K8s.Conn`)](./connections.md)
* [Operations (`K8s.Operation`)](./operations.md)
* [Discovery (`K8s.Discovery`)](./discovery.md)
* [Middleware (`K8s.Middleware`)](./middleware.md)
* [Authentication (`K8s.Conn.Auth`)](./authentication.md)
* [Local Development and Testing](./testing.md)
  
TODO:
* module docs
* a few readme examples

Kubernetes API resources are discovered pre-request and resource definitions are cached (configurable). This library is currently tested against k8s OpenAPI specs: 1.1x and master.

## Custom Resource Definitions

Custom resources are discovered via the same mechanism as "standard" k8s resources and can be worked with as such:

Listing the `Greeting`s from the [`hello operator`](https://github.com/coryodaniel/hello_operator).

```elixir
operation = K8s.Client.list("hello-operator.example.com/v1", :greeting, [namespace: "default"])
{:ok, greeting} = K8s.Client.run(operation, :dev)
```

## Multiple Clusters

Copying a workloads between two clusters:

Register a staging cluster:

```elixir
staging_conn = K8s.Conn.from_file("~/.kube/config")
{:ok, staging} = K8s.Cluster.Registry.add(:staging, staging_conn)
```

Register a prod cluster:

```elixir
prod_conn = K8s.Conn.from_service_account() # or from_file/2
{:ok, prod} = K8s.Cluster.Registry.add(:prod, staging_conn)
```

Get a list of all deployments in the `default` prod namespace:

```elixir
operation = K8s.Client.list("apps/v1", :deployment, namespace: "default")
{:ok, deployments} = K8s.Client.run(operation, :prod)
```

Map the deployments to operations and async create on staging:

```elixir
deployments
|> Enum.map(fn(deployment) -> K8s.Client.create(deployment) end)
|> K8s.Client.async(:staging)
```

## Adding Authorization Providers

```elixir
config :k8s, auth_providers: [My.Custom.Provider]
```

Providers are checked in order, the first to return an authorization struct wins.

Custom providers are processed before default providers.

For protocol and behavior implementation examples check out `Certificate`, `Token`, or `AuthProvider` [here](../lib/k8s/conn/auth/).

## Performing sub-resource operations

Subresource (eviction|finalize|bindings|binding|approval|scale|status) operations are created in the same way as standard operations using `K8s.Operation.build/4`, `K8s.Operation.build/5`, or any `K8s.Client` function.

Getting a deployment's status:

```elixir
cluster = :test
operation = K8s.Client.get("apps/v1", "deployments/status", name: "nginx", namespace: "default")
{:ok, scale} = K8s.Client.run(operation, cluster)
```

Getting a deployment's scale:

```
cluster = :test
operation = K8s.Client.get("apps/v1", "deployments/scale", [name: "nginx", namespace: "default"])
{:ok, scale} = K8s.Client.run(operation, cluster)
```

There are two forms for mutating subresources.

Evicting a pod with a Pod map:

```elixir
cluster = :test
eviction = %{
  "apiVersion" => "policy/v1beta1",
  "kind" => "Eviction",
  "metadata" => %{
    "name" => "nginx",
  }
}

# Here we use K8s.Resource.build/4 but this k8s resource map could be built manually or retrieved from the k8s API
subject = K8s.Resource.build("v1", "Pod", "default", "nginx")
operation = K8s.Client.create(subject, eviction)
{:ok, resp} = K8s.Client.run(operation, cluster)
```

Evicting a pod by providing details:

```elixir
cluster = :test
eviction = %{
  "apiVersion" => "policy/v1beta1",
  "kind" => "Eviction",
  "metadata" => %{
    "name" => "nginx",
  }
}

subject = K8s.Client.create("v1", "pods/eviction", [namespace: "default", name: "nginx"], eviction)
operation = K8s.Client.create(subject, eviction)
{:ok, resp} = K8s.Client.run(operation, cluster)
