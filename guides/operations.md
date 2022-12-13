# HTTP Operations (`K8s.Operation`)

`K8s.Operation`s are Kubernetes REST operations. They encapsulate all the details of an HTTP request _except_ the server to perform them against.

Many more client examples exist in the `K8s.Client` docs.

## Creating a Deployment from a Map

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
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")
{:ok, response} = K8s.Client.run(conn, operation)
```

## Creating a Deployment from a YAML File

`K8s.Resource` provides YAML resource parsing and interpolation support as well as a few helper functions for accessing common Kubernetes resource fields.

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
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")
{:ok, deployment} = K8s.Client.run(conn, operation)
```

## Listing Deployments

In a given namespace:

```elixir
operation = K8s.Client.list("apps/v1", "Deployment", namespace: "prod")
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")
{:ok, deployments} = K8s.Client.run(conn, operation)
```

Across all namespaces:

```elixir
operation = K8s.Client.list("apps/v1", "Deployment", namespace: :all)
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")
{:ok, deployments} = K8s.Client.run(conn, operation)
```

_Note:_ `K8s.Client.list` will return a `map`. The list of resources will be under `"items"`.

## Using `labelSelector` with List Operations

`K8s.Selector` supports programatically building Kubernetes `labelSelector`s.

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")

operation =
  K8s.Client.list("apps/v1", :deployments)
  |> K8s.Selector.label({"app", "nginx"})
  |> K8s.Selector.label_in({"environment", ["qa", "prod"]})

K8s.Client.run(conn, operation)
```

## Getting a Deployment

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")
operation = K8s.Client.get("apps/v1", :deployment, [namespace: "default", name: "nginx-deployment"])
{:ok, deployment} = K8s.Client.run(conn, operation)
```

## Watch Operations (`K8s.Client.Runner.Watch`)

Watch operations use the Kubernetes Watch API to stream `added`, `modified`, and `deleted` as they occur.

To get a stream of events:

```elixir
operation = K8s.Client.watch("apps/v1", :deployment, namespace: :all)
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")
{:ok, event_stream} = K8s.Client.stream(conn, operation)
```

## Wait on a Resource (`K8s.Client.Runner.Wait`)

The wait runner permits read operations to be made and block until a certain state is met in Kubernetes.

This follow example will wait 60 seconds for the field `status.succeeded` to equal `1`.

```elixir
operation = K8s.Client.get("batch/v1", :job, namespace: "default", name: "database-migrator")
wait_opts = [find: ["status", "succeeded"], eval: 1, timeout: 60]
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")
{:ok, job} = K8s.Client.wait_until(conn, operation, wait_opts)
```

`:find` and `:eval` also accept functions to apply to check success.

## Async Batch Operations (`K8s.Client.Runner.Async`)

An async runner is provided for running operations in parallel. All operations are fired async and their results are returned. Processing does not halt if an error occurs for one operation.

```elixir
operation1 = K8s.Client.get("v1", "Pod", namespace: "default", name: "pod-1")
operation2 = K8s.Client.get("v1", "Pod", namespace: "default", name: "pod-2")

{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")
results = K8s.Client.async(conn, [operation1, operation2])
```

`results` will be a list of `:ok` and `:error` tuples.

## List Operations as Elixir Streams (`K8s.Client.Runner.Stream`)

A stream runner is provided to automatically handle pagination in `K8s.Client.list/3` operations.

```elixir
operation = K8s.Client.list("v1", "Pod", namespace: :all)
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")

conn
|> K8s.Client.stream(operation)
|> Stream.filter(&my_filter_function?/1)
|> Stream.map(&my_map_function?/1)
|> Enum.into([])
```

## Connect to pods and execute commands

The `:connect` operation is used to connect to pods and execute commands.
A `:connect` operation is created with `K8s.Client.connect/N`. Be sure to pass
the command you want to run in the options.

### Waiting for command termination

If you want to run a command that terminates and wait for it, pass the `:connect`
operation to `K8s.Client.run/N`.

```elixir
  {:ok, conn} = K8s.Conn.from_file("~/.kube/config")

  op = K8s.Client.connect(
    "v1",
    "pods/exec",
    [namespace: "default", name: "nginx-8f458dc5b-zwmkb"],
    command: ["/bin/sh", "-c", "nginx -t"]
  )

  {:ok, response} = K8s.Client.run(conn, op)
```

### Opening long-lasting connections (e.g. a shell) and sending messages to pods

If you send a command that does not terminate (e.g. `/bin/sh`) or one that takes
long to terminate, you can open the connection in a separate process and stream
the response. Further, you can `send/2` messages to that process (e.g. further
commands). See the example below.

```elixir
  {:ok, conn} = K8s.Conn.from_file("~/.kube/config")

  op = K8s.Client.connect(
    "v1",
    "pods/exec",
    [namespace: "default", name: "nginx-8f458dc5b-zwmkb"],
    command: ["/bin/sh"]
  )

  parent_process = self()

  task = Task.async(fn ->
    {:ok, stream} = K8s.Client.stream(conn, op)

    stream
    |> Stream.map(&send(parent_process, &1))
    |> Stream.run()
  end)

  # wait for connection to be established
  receive(do: (:open -> :ok)

  send(task.pid, {:stdin, ~s(echo "hello world"\n)})

  # you receive "hello world" on stdout
  receive(do: ({:stdout, message} -> IO.puts(message))

  # close the connection, the task will terminate.
  send(task.pid, :close)
```

### Options

- `command` - required for running commands
- `container` - if a pod runs multiple containers, you have to specify the container to run the command in.
- `stdin` - enable stdin (defaults to `true`)
- `stdout` - enable stdout (defaults to `true`)
- `stderr` - enable stderr (defaults to `true`)
- `tty` - stdin is a TTY (defaults to `false`)

```elixir
  {:ok, conn} = K8s.Conn.from_file("~/.kube/config")

  op = K8s.Client.connect(
    "v1",
    "pods/exec",
    [namespace: "default", name: "nginx-8f458dc5b-zwmkb"],
    command: ["/bin/sh", "-c", "nginx -t"],
    container: "main",
    tty: true
  )

  {:ok, response} = K8s.Client.run(conn, op)
```
