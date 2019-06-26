# K8s

[K8s](https://hexdocs.pm/k8s/readme.html) - Kubernetes API Client for Elixir

[![Build Status](https://travis-ci.org/coryodaniel/k8s.svg?branch=master)](https://travis-ci.org/coryodaniel/k8s)
[![Coverage Status](https://coveralls.io/repos/github/coryodaniel/k8s/badge.svg?branch=master)](https://coveralls.io/github/coryodaniel/k8s?branch=master)
[![Hex.pm](http://img.shields.io/hexpm/v/k8s.svg?style=flat)](https://hex.pm/packages/k8s)
[![Documentation](https://img.shields.io/badge/documentation-on%20hexdocs-green.svg)](https://hexdocs.pm/k8s/)
![Hex.pm](https://img.shields.io/hexpm/l/k8s.svg?style=flat)

## Features

* A client API for humans
* Kubernetes resources, groups, and CRDs are autodiscovered at boot time. No swagger file to include or override.
* Client supports standard HTTP calls, async batches, wait on status, and watchers
* Supports multiple clusters
* Supports multiple authentication credentials
  * serviceaccount
  * token
  * certificate
  * auth-provider
* Supports multiple kubernetes API
* Tested against kubernetes swagger specs: 1.10+ and master
* CRD support
* Kubernetes resource and version helper functions
* Kube config file parsing
* Certificate and service account based auth
* Pluggable auth providers
* Macro free; fast compile & fast startup

## Installation

The package can be installed by adding `k8s` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:k8s, "~> 0.2"}
  ]
end
```

## Usage

Check out the [Usage Guide](https://hexdocs.pm/k8s/usage.html) for in-depth examples.

Most functions are also written using doctests.

* [K8s.Client doctests](https://hexdocs.pm/k8s/K8s.Client.html)
* [K8s.Cluster doctests](https://hexdocs.pm/k8s/K8s.Cluster.html)
* [K8s.Conf doctests](https://hexdocs.pm/k8s/K8s.Conf.html)
* [K8s.Resource doctests](https://hexdocs.pm/k8s/K8s.Resource.html)
* [K8s.Version doctests](https://hexdocs.pm/k8s/K8s.Version.html)

## Testing

### Adding support for a new version of kubernetes

Download the swagger spec for the new version. `k8s` doesn't use swagger to define the API, but it is used to drive property tests.

```shell
export NEW_VERSION_NUMBER=1.1n
make get/${NEW_VERSION_NUMBER}
```

```shell
make test/${NEW_VERSION_NUMBER}
```

A [mock `Discovery`](.test/support/mock/discovery.ex) module exist populated by [this JSON config](./test/support/mock/data/groups.json) to simulate runtime API discovery.

If new resources or APIs were added to kubernetes in the new version you will likely see one of these errors: `unsupported_group_version` and `unsupported_kind`.

### Unsupported Group Version errors

This error occurs when a new API is added to kubernetes.

Example: `{:error, :unsupported_group_version, "scheduling.k8s.io/v1"}`

Add the `:unsupported_group_version` to the mock configuration and rerun the test suite.

A config entry looks like:

```javascript
// ...
 {
    "groupVersion": "scheduling.k8s.io/v1", // add the group version name
    "kind": "APIResourceList", // leave as is
    "resources": [ // add a list of resources provided by the new `groupVersion`
      {
        "kind": "PriorityClass", // `kind` name
        "name": "priorityclasses", // plural name
        "namespaced": false, // namespaced or not
        "singularName": "",
        "verbs": [ // list of verbs supported by the new API
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
// ...
```

### Unsupported Kind errors

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
