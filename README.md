# K8s

[K8s](https://hexdocs.pm/k8s/readme.html) - Kubernetes API Client for Elixir

[![Build Status](https://travis-ci.org/coryodaniel/k8s.svg?branch=master)](https://travis-ci.org/coryodaniel/k8s)
[![Coverage Status](https://coveralls.io/repos/github/coryodaniel/k8s/badge.svg?branch=master)](https://coveralls.io/github/coryodaniel/k8s?branch=master)
[![Hex.pm](http://img.shields.io/hexpm/v/k8s.svg?style=flat)](https://hex.pm/packages/k8s)
[![Documentation](https://img.shields.io/badge/documentation-on%20hexdocs-green.svg)](https://hexdocs.pm/k8s/)
![Hex.pm](https://img.shields.io/hexpm/l/k8s.svg?style=flat)

## Features

* A client API for humans 👩🏼🧑👩🏻👩🏽👩🏾🧑🏻🧑🏽🧑🧑🏾👨🏼👨🏾👨🏿
* 🔮 Kubernetes resources, groups, and CRDs are autodiscovered at boot time. No swagger file to include or override.
* Client supports standard HTTP calls, async batches, wait on status ⏲️, and watchers 👀
* ⚙️ HTTP Request middleware
* Multiple clusters ⚓ ⚓ ⚓
* 🔐 Multiple authentication credentials
  * 🤖 serviceaccount
  * token
  * 📜 certificate
  * auth-provider
  * Pluggable auth providers!
* 🆗 Tested against Kubernetes versions 1.10+ and master
* 🛠️ CRD support
* 📈 Integrated with `:telemetry`
* ℹ️ Kubernetes resource and version helper functions
* 🧰 Kube config file parsing
* 🏎️ Macro free; fast compile & fast startup

## Installation

The package can be installed by adding `k8s` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:k8s, "~> 0.5"}
  ]
end
```

## Usage

Check out the [Usage Guide](https://hexdocs.pm/k8s/usage.html) for in-depth examples.

Most functions are also written using doctests.

* [K8s.Client doctests](https://hexdocs.pm/k8s/K8s.Client.html)
* [K8s.Conn doctests](https://hexdocs.pm/k8s/K8s.Conn.html)
* [K8s.Resource doctests](https://hexdocs.pm/k8s/K8s.Resource.html)
* [K8s.Version doctests](https://hexdocs.pm/k8s/K8s.Version.html)

## Testing `K8s` operations in your application

`K8s` ships with a [`K8s.Client.DynamicHTTPProvider`](./lib/k8s/client/dynamic_http_provider.ex) for stubbing HTTP responses to kubernetes API requests.

This provider is used throughout the test suite for mocking HTTP responses.

```elixir
defmodule MyApp.ResourceTest do
  use ExUnit.Case, async: true

  defmodule K8sMock do
    @base_url "https://localhost:6443"
    @namespaces_url @base_url <> "/api/v1/namespaces"

    def request(:get, @namespaces_url, _, _, _) do
      namespaces = [%{"metadata" => %{"name" => "default"}}]
      body = Jason.encode!(namespaces)
      {:ok, %HTTPoison.Response{status_code: 200, body: body}}
    end
  end

  setup do
    DynamicHTTPProvider.register(self(), __MODULE__.K8sMock)
  end

  test "gets namespaces" do
    conn = %K8s.Conn{} # set up your conn
    operation = K8s.Client.get("v1", :namespaces)
    assert {:ok, namespaces} = K8s.Client.run(operation, conn)
    assert namespaces == [%{"metadata" => %{"name" => "default"}}]
  end
end
```

To see advanced examples of usage, check out these examples in the test suite:

* [client/runner/base](./test/k8s/client/runner/base_test.exs)
* [client/runner/stream](./test/k8s/client/runner/stream_test.exs)
* [client/runner/watch](./test/k8s/client/runner/watch_test.exs)
* [discovery](./test/k8s/discovery_test.exs)

## Contributing

### Adding support for a new version of kubernetes

Download the swagger spec for the new version. `k8s` doesn't use swagger to define the API, but it is used to drive property tests.

```shell
export NEW_VERSION_NUMBER=1.1n
make get/${NEW_VERSION_NUMBER}
```

```shell
make test/${NEW_VERSION_NUMBER}
```

Mock discovery [responses](.test/support/discovery) exist to simulate runtime API discovery using the [`FileDriver`](./lib/k8s/cluster/discover/file_driver.ex)

If new resources or APIs were added to kubernetes in the new version you will may see: `unsupported_resource`.

### Unsupported Resource errors

This error occurs when a new resource type is added to an existing API, similar to above you will need to add the `resource` to the list of `resources`.

The following config is missing `runtimeclasses` as a resource.

```javascript
  {
    "groupVersion": "node.k8s.io/v1beta1",
    "kind": "APIResourceList",
    "resources": [
      {
        "kind": "Node",
        "name": "nodes",
        "namespaced": false,
        "singularName": "",
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
  },
```

After mocking:

```javascript
  {
    "groupVersion": "node.k8s.io/v1beta1",
    "kind": "APIResourceList",
    "resources": [
      {
        "kind": "Node",
        "name": "nodes",
        "namespaced": false,
        "singularName": "",
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
        "kind": "RuntimeClass",
        "name": "runtimeclasses",
        "namespaced": false,
        "singularName": "",
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
  },
```
