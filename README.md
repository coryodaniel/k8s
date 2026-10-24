# K8s

[![Module Version](https://img.shields.io/hexpm/v/k8s.svg)](https://hex.pm/packages/k8s)
[![Coverage Status](https://coveralls.io/repos/github/coryodaniel/k8s/badge.svg?branch=develop)](https://coveralls.io/github/coryodaniel/k8s?branch=develop)
[![Last Updated](https://img.shields.io/github/last-commit/coryodaniel/k8s.svg)](https://github.com/coryodaniel/k8s/commits/develop)

[![Build Status CI](https://github.com/coryodaniel/k8s/actions/workflows/ci.yaml/badge.svg)](https://github.com/coryodaniel/k8s/actions/workflows/ci.yaml)
[![Build Status Elixir](https://github.com/coryodaniel/k8s/actions/workflows/elixir_matrix.yaml/badge.svg)](https://github.com/coryodaniel/k8s/actions/workflows/elixir_matrix.yaml)
[![Build Status K8s](https://github.com/coryodaniel/k8s/actions/workflows/k8s_matrix.yaml/badge.svg)](https://github.com/coryodaniel/k8s/actions/workflows/k8s_matrix.yaml)

[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/k8s/)
[![Total Download](https://img.shields.io/hexpm/dt/k8s.svg)](https://hex.pm/packages/k8s)
[![License](https://img.shields.io/hexpm/l/k8s.svg)](https://github.com/coryodaniel/k8s/blob/develop/LICENSE)

[K8s](https://hexdocs.pm/k8s/usage.html) - Kubernetes API Client for Elixir

## Features

- A client API for humans 👩🏼🧑👩🏻👩🏽👩🏾🧑🏻🧑🏽🧑🧑🏾👨🏼👨🏾👨🏿
- 🔮 Kubernetes resources, groups, and CRDs are autodiscovered at boot time. No swagger file to include or override.
- Client supports standard HTTP calls, async batches, wait on status ⏲️, and watchers 👀
- ⚙️ HTTP Request middleware
- Multiple clusters ⚓ ⚓ ⚓
- 🔐 Multiple authentication credentials
  - 🤖 serviceaccount
  - token
  - 📜 certificate
  - auth-provider
  - Pluggable auth providers!
- 🆗 Tested against Kubernetes versions 1.10+ and master
- 🛠️ CRD support
- 📈 Integrated with `:telemetry`
- ℹ️ Kubernetes resource and version helper functions
- 🧰 Kube config file parsing
- 🏎️ Macro free; fast compile & fast startup

## Installation

The package can be installed by adding `:k8s` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:k8s, "~> 2.0"}
  ]
end
```

## Usage

Check out the [Usage Guide](https://hexdocs.pm/k8s/usage.html) for in-depth examples. If you like
learning with Livebook, check out [kino_k8s](https://github.com/mruoss/kino_k8s). It comes with
nice smart cells to help you generate your first working code.

Most functions are also written using doctests.

- [K8s.Client doctests](https://hexdocs.pm/k8s/K8s.Client.html)
- [K8s.Conn doctests](https://hexdocs.pm/k8s/K8s.Conn.html)
- [K8s.Resource doctests](https://hexdocs.pm/k8s/K8s.Resource.html)
- [K8s.Version doctests](https://hexdocs.pm/k8s/K8s.Version.html)

If you are interested in building Kubernetes Operators or Schedulers, check out [Bonny](https://github.com/coryodaniel/bonny).

## Runtime JSON/YAML libraries

`k8s` supports configurable JSON and YAML libraries via application config.

```elixir
config :k8s,
  json_library: Jason,
  yaml_library: YamlElixir
```

These options are resolved at compile time. Recompile the project after changing either option.

For `:glazer` library use `Glazer.JSON` and the built-in adapter module `K8s.Yaml.Glazer`:

```elixir
config :k8s,
  json_library: Glazer.JSON,
  yaml_library: K8s.Yaml.Glazer
```

Expected callback functions:

- `json_library`: `encode!/1`, `decode!/1`
- `yaml_library`: `read_from_file/1`, `read_from_string/1`, `read_all_from_string/1`

Defaults are `Jason` and `YamlElixir`.

## tl;dr Examples

### Configure a cluster connection

Cluster connections can be created using the `K8s.Conn` module.

`K8s.Conn.from_file/1` will use the current context in your kubeconfig.

```elixir
{:ok, conn} = K8s.Conn.from_file("path/to/kubeconfig.yaml")
```

`K8s.Conn.from_file/2` accepts a keyword list to set the `:user`, `:cluster`, and/or `:context`

Connections can also be created in-cluster from a service account.

```elixir
{:ok, conn} = K8s.Conn.from_service_account("/path/to/service-account/directory")
```

Check out the [connection guide](https://hexdocs.pm/k8s/connections.html) for additional details.

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
