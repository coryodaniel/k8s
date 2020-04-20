# K8s

[K8s](https://hexdocs.pm/k8s/usage.html) - Kubernetes API Client for Elixir

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

If you are interested in building Kubernetes Operators or Schedulers, check out [Bonny](https://github.com/coryodaniel/bonny).

### tl;dr Examples


#### Configure a cluster

There are many ways to configure cluster connections. Check out the [guide](https://hexdocs.pm/k8s/connections.html) for additional options.

In `config.exs`:

```elixir
config :k8s,
  clusters: %{
    default: %{ # <- this can be any name, used to load connections later
      # Path to kube config
      conn: "~/.kube/config",
      # By default current context will be used, you can change the user or cluster
      conn_opts: [user: "some-user", cluster: "prod-cluster"]
    }
  }
```


#### Creating a deployment

```elixir
{:ok, conn} = K8s.Conn.lookup(:prod_us_east1)

opts = [namespace: "default", name: "nginx", image: "nginx:nginx:1.7.9"]
{:ok, resource} = K8s.Resource.from_file("priv/deployment.yaml", opts)

operation = K8s.Client.create(resource)
{:ok, deployment} = K8s.Client.run(operation, conn)
```

#### Listing deployments

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

#### Getting a deployment

```elixir
{:ok, conn} = K8s.Conn.lookup(:prod_us_east1)

operation = K8s.Client.get("apps/v1", :deployment, [namespace: "default", name: "nginx-deployment"])
{:ok, deployment} = K8s.Client.run(operation, conn)
```
