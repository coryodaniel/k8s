# K8s

[K8s](https://hexdocs.pm/k8s/readme.html) - Kubernetes API Client for Elixir

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

## Usage

Check out the [Usage Guide](https://hexdocs.pm/k8s/usage.html) for in-depth examples.

Most functions are also written using doctests.

* [K8s.Client doctests](https://hexdocs.pm/k8s/K8s.Client.html)
* [K8s.Cluster doctests](https://hexdocs.pm/k8s/K8s.Cluster.html)
* [K8s.Conf doctests](https://hexdocs.pm/k8s/K8s.Conf.html)
* [K8s.Resource doctests](https://hexdocs.pm/k8s/K8s.Resource.html)
* [K8s.Version doctests](https://hexdocs.pm/k8s/K8s.Version.html)

## Features

* A client API for humans
* Kubernetes resources, groups, and CRDs are autodiscovered at boot time. No swagger file to include or override.
* Client supports standard HTTP calls, async batches, wait on status, and watchers
* Supports multiple clusters
* Supports multiple authentication credentials
* Supports multiple kubernetes API
* Tested against kubernetes swagger specs: 1.10+ and master
* CRD support
* Kubernetes resource and version helper functions
* Kube config file parsing
* Certificate and service account based auth
* Pluggable auth providers
* Macro free; fast compile & fast startup

### Non-features

* Modules for every kubernetes resource.
* K8s.Client does *not* assuming "default" namespaces. Always provide a namespace when a namespace is applicable.
* No support the deprecated Watch API.
* Connect URLs aren't supported.

## Docs

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/k8s](https://hexdocs.pm/k8s).
