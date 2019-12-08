# Usage

* [Connections (`K8s.Conn`)](./guides/connections.md)
* [Operations](./guides/operations.md)
* [Custom Middleware](./guides/middleware.md)
* [Custom Auth Providers](./guides/auth-providers.md)
* [Testing](./guides/testing.md)


## Configuration

config :k8s,
  auth_providers: [],
  discovery_driver: K8s.Discovery.Driver.File,
  discovery_opts: [config: "test/support/discovery/example.json"],
  clusters: %{
    dev: %{
      conn: "~/.kube/config",
      conn_opts: [context: "docker-for-desktop"]
    },
    test: %{
      conn: "test/support/kube-config.yaml",
      conn_opts: [
        discovery_driver: K8s.Discovery.Driver.File,
        discovery_opts: [config: "test/support/discovery/example.json"]
      ]
    }
  }


config :k8s,
  discovery: %{
    driver: K8s.Discovery.Driver.File,
    opts: %{config: "test/support/discovery/example.json"}
  },
  conns: %{
    dev: %{
      config_path: "~/.kube/config",
      #service_account_path: "/var/run/..."
      #use_service_account: true,
      opts: %{
        context: "docker-for-desktop",
        discovery: %{
          driver: K8s.Discovery.Driver.HTTP,
          opts: %{cache: false}
        }
      }
    }
  }


## Registering Connections

`K8s.Conn`s can be registered via `config.exs` or environment variables. `K8s.Conn`s may also be built programmaticaly.

Connections are referenced by cluster name (`:default` below) when using a `K8s.Client`. Multiple clusters can be registered via config or at runtime.

Kubernetes API resources are discovered pre-request and resource definitions are cached (configurable). This library is currently tested against k8s OpenAPI specs: 1.1x and master.

See `K8s.Conn.Config`.

### Registering Clusters at Compile Time (config.exs)

Adding a cluster named `:default` using `~/.kube/config`. Defaults to `current-context` of the kube config file.

```elixir
config :k8s,
  clusters: %{
    default: %{
      conn: "~/.kube/config"
    }
  }
```

Using an alternate context:

```elixir
config :k8s,
  clusters: %{
    default: %{
      conn: "~/.kube/config"
      conn_opts: [context: "other-context"]
    }
  }
```

Setting cluster and user explicitly:

```elixir
config :k8s,
  clusters: %{
    default: %{
      conn: "~/.kube/config"
      conn_opts: [user: "some-user", cluster: "prod-cluster"]
    }
  }
```

Using a pod's service account (`pod.spec.serviceAccountName`):

A cluster name with a blank configuration will default to using the pod's service account.

```elixir
config :k8s, clusters: %{
  default: %{}
}
```

### Registering Clusters with Environment Variables

Multiple clusters can be registered via environment variables. Keep in mind that under the hood, `k8s` uses `kubeconfig` files.

**Environment Variable Prefixes:**

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

### Building `K8s.Conn`s programmatically

*TODO*

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

### Using `labelSelector` with list operations

```elixir
K8s.Client.list("apps/v1", :deployments)
|> K8s.Selector.label({"app", "nginx"})
|> K8s.Selector.label_in({"environment", ["qa", "prod"]})
|> K8s.Client.run(:default)
```

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

## List operations as a Elixir Streams

```elixir
operation = K8s.Client.list("v1", "Pod", namespace: :all)

operation
|> K8s.Client.stream()
|> Stream.filter(&my_filter_function?/1)
|> Stream.map(&my_map_function?/1)
|> Enum.into([])
```

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
