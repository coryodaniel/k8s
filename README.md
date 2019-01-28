# K8s

[K8s](https://hexdocs.pm/k8s/readme.html) - A Kubernetes client for Elixir

[![Build Status](https://travis-ci.org/coryodaniel/k8s.svg?branch=master)](https://travis-ci.org/coryodaniel/k8s)
[![Coverage Status](https://coveralls.io/repos/github/coryodaniel/k8s/badge.svg?branch=master)](https://coveralls.io/github/coryodaniel/k8s?branch=master)
[![Hex.pm](http://img.shields.io/hexpm/v/k8s.svg?style=flat)](https://hex.pm/packages/k8s)
[![Documentation](https://img.shields.io/badge/documentation-on%20hexdocs-green.svg)](https://hexdocs.pm/k8s/)
![Hex.pm](https://img.shields.io/hexpm/l/k8s.svg?style=flat)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `k8s` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:k8s, "~> 0.2"}
  ]
end
```

## Features

* Kubernetes resources, groups, and CRDs are autodiscovered at boot time. No swagger file to include or override.
* Client supports standard HTTP calls, async batches, wait on status, and watchers
* Supports multiple clusters
* Supports multiple authentication credentials
* Supports multiple kubernetes API
* A client API for humans
* CRD support
* Tested against kubernetes versions: 1.10, 1.11, 1.12, 1.13, and master
* Kubernetes resource and version helper functions
* Macro free; fast compile & fast startup
* Pluggable auth providers
* Kube config file parsing
* Certificate and service account based auth
* mix task for fetching kubernetes API specs

### Non-features

* Modules for every resource. The client always return string-keyed maps.
* K8s.Client does *not* assuming "default" namespaces. Always provide a namespace when a namespace is applicable.
* Will not support the deprecated Watch API
* Connect URLs aren't currently supported
* Finalize, binding, scale, and approval subresources aren't currently supported

## Registering Clusters

Clusters can be registered via `config.exs` or directly with `K8s.Cluster.register/3`.

Clusters are referenced by name (`:default` below) when using a `K8s.Client`. Multiple clusters can be registered via config.

This library ships with Kubernetes specs 1.10, 1.11, 1.12, and 1.13.

### Registering clusters via config

Adding a cluster named `:default` using `~/.kube/config`

```elixir
config :k8s,
  clusters: %{
    default: %{
      conf: "~/.kube/config",
      group_version: "1.13"
    }
  }
```

### Registering clusters directly

The below will register a cluster named `"1.13"` using `~/.kube.config` to connect. There are many options for loading a config, this will load the user and cluster from the `current-context`.

```elixir
conf = K8s.Conf.from_file("~/.kube/config")
routes = K8s.Router.generate_routes("./priv/swagger/1.13.json")

K8s.Cluster.register("1.13", routes, conf)
```

*Note:* Kubernetes API specs can be downloaded using `mix k8s.swagger --version 1.13`.

### Adding authorization providers

```elixir
config :k8s, auth_providers: [My.Custom.Provider]
```

Providers are checked in order, the first to return an authorization struct wins.

Custom providers are processed before default providers.

See [Certicate](lib/k8s/conf/auth/certificate.ex) and [Token](lib/k8s/conf/auth/token.ex) for protocol and behavior implementations.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/k8s](https://hexdocs.pm/k8s).
