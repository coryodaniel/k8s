# K8s

[K8s](https://hexdocs.pm/k8s/readme.html) - Kubernetes elixir client

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
    {:k8s, "~> 0.1"}
  ]
end
```

## TODO

Terminology should be "cluster" not router when specificying target
merge other library issues + Readme/moduledocs

Create a dry run runner
Create a when runner that dispatch is a function when a condition is met
  Spawns task, runs `until` and when true | error, dispatches function
Create a watch runner
bring your own resource

## Features

* K8s.Conf parsing and auth signing
  * Custom auth providers
  * Multiple configurations
* K8s.Resource
* K8s.Version
* K8s.Client, async batch, wait, when, watch
* K8s.Router -> K8s.Cluster
  * supports multiple kubernets APIs
  * supports custom swagger specs and CRDs
* Fast compile & fast startup
* API for humans
* Tested against elixir versions (), otp (), and k8s( 1.10, 1.11, 1.12, 1.13, master)

## Non-features
* Not assuming "default" namespaces. *Note:* Always provide namespace when using K8s.Client functions
* Deprecated Watch API
* Connect URIs
* ... rest of exclusions list

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/k8s](https://hexdocs.pm/k8s).

# K8s.Conf
## Usage

```elixir
# Defaults to 'current-context', optionally set cluster, context, or user
# opts = [
#   user: "alt-user",
#   cluster: "alt-cluster",
#   context: "alt-context"
# ]

opts = []
config = K8s.Conf.from_file("~/.kube/config", opts)

# Optionally load from a service account
# config = K8s.Conf.from_service_account()

http_request_options = K8s.Conf.RequestOptions.generate(config)
[header: headers, ssl_options: ssl_options] = http_request_options

# Add headers and SSL options to HTTP library of choice
```

### Adding authorization providers

```elixir
config :k8s, auth_providers: [My.Custom.Provider]
```

Providers are checked in order, the first to return an authorization struct wins.

Custom providers are processed before default providers.

See [Certicate](lib/k8s/conf/auth/certificate.ex) and [Token](lib/k8s/conf/auth/token.ex) for protocol and behavior implementations.
