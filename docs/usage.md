# Usage

## Registering Clusters

Clusters can be registered via `config.exs` or directly with `K8s.Cluster.register/2`.

Clusters are referenced by name (`:default` below) when using a `K8s.Client`. Multiple clusters can be registered via config or at runtime.

Kubernetes API resources are auto-discovered at boot time. This library is currently tested against k8s OpenAPI specs: 1.10, 1.11, 1.12, 1.13, and master.

### Registering Clusters at Run Time

The below will register a cluster named `:prod` using `~/.kube.config` to connect. There are many options for loading a config, this will load the user and cluster from the `current-context`.

```elixir
conf = K8s.Conf.from_file("~/.kube/config")
K8s.Cluster.register(:prod, conf)
```

Registering a cluster using the k8s' ServiceAccount of the pod:

```elixir
conf = K8s.Conf.from_service_account()
K8s.Cluster.register(:prod, conf)
```

### Registering Clusters at Compile Time (config.exs)

Adding a cluster named `:default` using `~/.kube/config`. Defaults to `current-context` of the kube config file.

```elixir
config :k8s,
  clusters: %{
    default: %{
      conf: "~/.kube/config"
    }
  }
```

Using an alternate context:

```elixir
config :k8s,
  clusters: %{
    default: %{
      conf: "~/.kube/config"
      conf_opts: [context: "other-context"]
    }
  }
```

Setting cluster and user explicitly:

```elixir
config :k8s,
  clusters: %{
    default: %{
      conf: "~/.kube/config"
      conf_opts: [user: "some-user", cluster: "prod-cluster"]
    }
  }
```

## Running an operation

Many more client examples exist in the `K8s.Client` docs.

### Creating a Deployment from a Map

```elixir
resource = %{
  "apiVersion" => "apps/v1",
  "kind" => "Deployment",
  "metadata" => %{
    "labels" => %{"app" => "nginx"},
    "name" => "nginx-deployment",
    "namespace" => "default"
  },
  "spec" => %{
    "replicas" => 3,
    "selector" => %{"matchLabels" => %{"app" => "nginx"}},
    "template" => %{
      "metadata" => %{"labels" => %{"app" => "nginx"}},
      "spec" => %{
        "containers" => [
          %{
            "image" => "nginx:1.7.9",
            "name" => "nginx",
            "ports" => [%{"containerPort" => 80}]
          }
        ]
      }
    }
  }
}

operation = K8s.Client.create(resource)
{:ok, response} = K8s.Client.run(operation, :dev)
```

### Creating a Deployment from a YAML file

Given the YAML file `priv/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <%= name %>-deployment
  namespace: <%= namespace %>
  labels:
    app: <%= name %>
spec:
  replicas: 3
  selector:
    matchLabels:
      app: <%= name %>
  template:
    metadata:
      labels:
        app: <%= name %>
    spec:
      containers:
      - name: <%= name %>
        image: <%= image %>
        ports:
        - containerPort: 80
```

```elixir
opts = [namespace: "default", name: "nginx", image: "nginx:nginx:1.7.9"]
resource = K8s.Resource.from_file!("priv/deployment.yaml", opts)

operation = K8s.Client.create(resource)
{:ok, deployment} = K8s.Client.run(operation, :dev)
```

### Listing Deployments

In a given namespace:

```elixir
operation = K8s.Client.list("apps/v1", "Deployment", namespace: "prod")
{:ok, deployments} = K8s.Client.run(operation, :dev)
```

Across all namespaces:

```elixir
operation = K8s.Client.list("apps/v1", "Deployment", namespace: :all)
{:ok, deployments} = K8s.Client.run(operation, :dev)
```

*Note:* `K8s.Client.list` will return a `map`. The list of resources will be under `"items"`.

### Getting a Deployment

```elixir
operation = K8s.Client.get("apps/v1", :deployment, [namespace: "default", name: "nginx-deployment"])
{:ok, deployment} = K8s.Client.run(operation, :dev)
```

## Watch Operations

```elixir
operation = K8s.Client.list("apps/v1", :deployment, namespace: :all)
{:ok, reference} = K8s.Client.watch(operation, :dev, stream_to: self())
```

Kubernetes Watch API added, modified, and deleted events will be streamed as they occur.

## Wait on a Resource

This will wait 60 seconds for the field `status.succeeded` to equal `1`. `:find` and `:eval` also accept functions to apply to check success.

```elixir
operation = K8s.Client.get("batch/v1", :job, namespace: "default", name: "database-migrator")
wait_opts = [find: ["status", "succeeded"], eval: 1, timeout: 60]
{:ok, job} = K8s.Client.wait(op, cluster_name, wait_opts)
```

## Batch Operations

Fetching two pods at once.

```elixir
operation1 = K8s.Client.get("v1", "Pod", namespace: "default", name: "pod-1")
operation2 = K8s.Client.get("v1", "Pod", namespace: "default", name: "pod-2")

# results will be a list of :ok and :error tuples
results = K8s.Client.async([operation1, operation2], :dev)
```

*Note*: all operations are fired async and their results are returned. Processing does not halt if an error occurs for one operation.

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
staging_conf = K8s.Conf.from_file("~/.kube/config")
staging = K8s.Cluster.register(:staging, staging_conf)
```

Register a prod cluster:

```elixir
prod_conf = K8s.Conf.from_service_account() # or from_file/2
prod = K8s.Cluster.register(:prod, staging_conf)
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

See [Certificate](lib/conf/auth/certificate.ex) and [Token](lib/conf/auth/token.ex) for protocol and behavior implementations.
