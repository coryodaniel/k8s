# Discovery (`K8s.Discovery`)

`k8s` supports _just-in-time_ discovery of cluster APIs and resource kinds. This is important because depending on the CRDs, Kubernetes version, and enabled APIs, URL paths can vary.

The goal of the `k8s` library was to support multiple clusters without the need to generate code from Kubernetes swagger files. This makes the library more portable and easier to use with various clusters.

`K8s.Discovery` is pluggable. It was designed in this manner to ease testing. The `K8s.Discovery.Driver.HTTP` driver is _probably_ the only driver you will need to use in development and production.

A file driver (`K8s.Discovery.Driver.File`) is also provided. This is used in the test suite to "stub" discovery without making HTTP requests. The file driver could also be used in the scenario that you want to limit calls to the Kubernetes masters either out to reduce the number of HTTP calls or for security if the master's API metadata is inaccessible (`kubectl api-versions`, `kubectl api-resources`).

## Using the Discovery module

Discovery is done automatically during HTTP requests, but the module can also be used directly.

Available functions are:

* `K8s.Discovery.versions/2` - list API versions of the cluster
* `K8s.Discovery.resources/3` - list resource kinds of a specific API
* `K8s.Discovery.url_for/2` - Generate the URL for a `K8s.Operation` on a specific `K8s.Conn`

## Setting the Default Driver

Drivers can be set via a Mix config. A default driver can be specified as well as a driver per registered connection.

`discovery_driver` and `discovery_opts` control the default driver to use. If not set, the HTTP driver will be used with an empty keyword list.

Below the file driver is set as the default using `"test/support/discovery/example.json"` as the configuration file (see _Using the File Driver_ below).

```elixir
use Mix.Config

config :k8s,
  discovery_driver: K8s.Discovery.Driver.File,
  discovery_opts: [config: "test/support/discovery/example.json"],
  clusters: %{
    test: %{
      conn: "test/support/kube-config.yaml"
    }
  }

```

## Setting Drivers per Connection

Drivers can also be set per connection.

In the example below the `:test` and `:dev` connections are using the default File driver, while the `:prod` connection is using the HTTP driver with caching enabled.

```elixir
use Mix.Config

config :k8s,
  discovery_driver: K8s.Discovery.Driver.File,
  discovery_opts: [config: "test/support/discovery/example.json"],
  clusters: %{
    test: %{
      conn: "test/support/kube-config.yaml",
      conn_opts: [context: "test-context"]
    },
    dev: %{
      conn: "test/support/kube-config.yaml",
      conn_opts: [context: "dev-context"]
    },
    prod: %{
      use_sa: true,
      conn_opts: [
        discovery_driver: K8s.Discovery.Driver.HTTP,
        discovery_opts: [cache: true]
      ]
    }
  }

```

## Using the HTTP Driver (`K8s.Discovery.Driver.HTTP`)

The HTTP driver is used by default. When a `K8s.Operation` is run calls to `/api` and `/apis` are made to discovery what resources, versions, and scope are supported for resources.

The HTTP driver can also be used directly to explore API support.

List supported versions:

```elixir
{:ok, conn} = K8s.Conn.lookup(:my_connection)
K8s.Discovery.Driver.HTTP.versions(conn)
["v1", "apps/v1", "batch/v1"]
```

List supported resources of an API version.

```elixir
{:ok, conn} = K8s.Conn.lookup(:my_connection)
K8s.Discovery.Driver.HTTP.resources("apps/v1", conn)
[
  {
    "kind": "DaemonSet",
    "name": "daemonsets",
    "namespaced": true,
    "verbs": [
      "create",
      "delete",
      "deletecollection",
      "get",
      "list",
      "patch",
      "update",
      "watch"
    ]
  },
  {
    "kind": "Deployment",
    "name": "deployments",
    "namespaced": true,
    "verbs": [
      "create",
      "delete",
      "deletecollection",
      "get",
      "list",
      "patch",
      "update",
      "watch"
    ]
  }
  # ...
]
```

## Using the File Driver (`K8s.Discovery.Driver.File`)

The file driver is primarly intended for testing. The format for a driver configuration file is a JSON file with API version as the key to a list of resource metadata.

```json
{
  "v1": [
    {
      "kind": "Namespace",
      "name": "namespaces",
      "namespaced": false,
      "verbs": [
        "create",
        "delete",
        "get",
        "list",
        "patch",
        "update",
        "watch"
      ]
    }
  ],
  "apps/v1": [
    {
      "kind": "Deployment",
      "name": "deployments",
      "namespaced": true,
      "verbs": [
        "create",
        "delete",
        "deletecollection",
        "get",
        "list",
        "patch",
        "update",
        "watch"
      ]
    }
  ]
}
```