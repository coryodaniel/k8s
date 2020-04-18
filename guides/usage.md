# Usage

* [Connections (`K8s.Conn`)](./connections.html)
* [Operations (`K8s.Operation`)](./operations.html)
* [Discovery (`K8s.Discovery`)](./discovery.html)
* [Middleware (`K8s.Middleware`)](./middleware.html)
* [Authentication (`K8s.Conn.Auth`)](./authentication.html)
* [Testing](./testing.html)
* [Advanced Topics](./advanced.html) - CRDs, Multiple Clusters, and Subresource Requests

## tl;dr Examples

### Creating a deployment

```elixir
{:ok, conn} = K8s.Conn.lookup(:prod_us_east1)

opts = [namespace: "default", name: "nginx", image: "nginx:nginx:1.7.9"]
{:ok, resource} = K8s.Resource.from_file("priv/deployment.yaml", opts)

operation = K8s.Client.create(resource)
{:ok, deployment} = K8s.Client.run(operation, conn)
```

### Listing deployments

In a namespace:

```elixir
{:ok, conn} = K8s.Conn.lookup(:prod_us_east1)

operation = K8s.Client.list("apps/v1", "Deployment", namespace: "prod")
{:ok, deployments} = K8s.Client.run(operation, conn)
```

Across all namespaces:

```elixir
{:ok, conn} = K8s.Conn.lookup(:prod_us_east1)

operation = K8s.Client.list("apps/v1", "Deployment", namespace: :all)
{:ok, deployments} = K8s.Client.run(operation, conn)
```

### Getting a deployment

```elixir
{:ok, conn} = K8s.Conn.lookup(:prod_us_east1)

operation = K8s.Client.get("apps/v1", :deployment, [namespace: "default", name: "nginx-deployment"])
{:ok, deployment} = K8s.Client.run(operation, conn)
```

### Running a command in a pod



If your Pod has only one container, then you do not have to specify which container to run the command.

```elixir
  conn = K8s.Conn.from_file("~/.kube/config")
  op = K8s.Client.create("v1", "pods/exec", [namespace: "prod", name: "nginx"])
  exec_opts = [command: ["/bin/sh", "-c", "nginx -t"], stdin: true, stderr: true, stdout: true, tty: true, stream_to: self()]
  {:ok, pid} = K8s.Client.exec(op, conn, exec_opts)

  # wait for the response from the pod
  receive do
    {:ok, message} -> #do something with the messages. There can be a lot of output.
    {:exit, {:remote, 1000, ""}} -> # The websocket closed because of normal reasons.
    error -> # Something unexpected happened.
  after
    60_0000 -> Process.exit(pid, :kill) # we probably dont want to let this run forever as this can leave orphaned processes.
  end
```

Same as above, but you explicitly set the container you want to run the command in. If your Pod has more than one container and you do not specify which container, you will get a 400 bad request back from k8s API.

```elixir
  conn = K8s.Conn.from_file("~/.kube/config")
  op = K8s.Client.create("v1", "pods/exec", [namespace: "prod", name: "nginx"])
  exec_opts = [command: ["/bin/sh", "-c", "gem list"], container: "fluentd", stdin: true, stderr: true, stdout: true, tty: true, stream_to: self()]
  {:ok, pid} = K8s.Client.exec(op, conn, exec_opts)

  receive do
    {:ok, message} -> #do something with the messages. There can be a lot of output.
    {:exit, {:remote, 1000, ""}} -> # The websocket closed because of normal reasons.
    error -> # Something unexpected happened.
  after
    60_0000 -> Process.exit(pid, :kill) # we probably dont want to let this run forever as this can leave orphaned processes.
  end
```

