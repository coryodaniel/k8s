# Authentication (`K8s.Conn.Auth`)

`k8s` features pluggable authentication, but includes 5 strategies in the order of attempted application:

* `K8s.Conn.Auth.Certificate` certificate based authentication
* `K8s.Conn.Auth.Token` token based authentication
* `K8s.Conn.Auth.AuthProvider` implements a Kubernetes config file's [`auth-provider`](https://banzaicloud.com/blog/kubeconfig-security/) functionality.
* `K8s.Conn.Auth.Exec` implements a Kubernetes config file's [`exec`](https://banzaicloud.com/blog/kubeconfig-security/)
 functionality.
* `K8s.Conn.Auth.BasicAuth` username/password basic auth

**A few notes first:**

1. [`K8s.Conn.Auth.AuthProvider`](https://github.com/coryodaniel/k8s/blob/develop/lib/k8s/conn/auth/auth_provider.ex) is itself an authentication strategy that allow shell calls to provide a Bearer Token. It's unfortunately named, but the names of the modules follow the key names in a Kubernetes config file. More on this strategy can be found [here](https://banzaicloud.com/blog/kubeconfig-security/).
   
2. The [`K8s.Conn`](https://github.com/coryodaniel/k8s/blob/develop/lib/k8s/conn.ex#L58) struct encapsulates a connection to a cluster. It has the cluster address as well as how to authenticate to the cluster. `K8s.Conn` structs can be constructed manually, but there are a few helpers here to create one.
   
3. The [`K8s.Conn.Auth.Token`](https://github.com/coryodaniel/k8s/blob/develop/lib/k8s/conn/auth/token.ex#L13-L14) auth strategy is probably the simplest strategy to review as a reference implementation.

## Custom Authentication Providers

Two things are required to implement a custom auth strategy:

1. Implement the [K8s.Conn.Auth](https://github.com/coryodaniel/k8s/blob/develop/lib/k8s/conn/auth.ex) **behaviour** for auth strategies. The first strategy to return an `{:ok, K8s.Conn.Auth}` struct will be chosen. Any that cannot authenticate the connection should return `:skip`.
   
2. Implement the [K8s.Conn.RequestOptions](https://github.com/coryodaniel/k8s/blob/develop/lib/k8s/conn/request_options.ex#L19) protocol which should create a `RequestOptions` struct. This struct is used to set HTTP Headers and SSL connection options.

Looking at the [Token](https://github.com/coryodaniel/k8s/blob/develop/lib/k8s/conn/auth/token.ex#L13-L14) example:

* Line 13 implements the case where this auth strategy would be able to generate request options
* Line 14 implements the default case where it cannot authenticate the request
* Lines 19-24 implement how to generate HTTP Headers and SSL options to be used by HTTPoison to make the HTTP requests.

## Using a Custom Authentication Provider

Authentication providers are traversed in order. The first provider to return an `K8s.Conn.Auth` struct is used. Default providers are checked _after_ any providers supplied to in the Mix config key `:auth_providers`:

```elixir
config :k8s, 
  auth_providers: [CustomProvider1, CustomProvider2]
```

This would result in authentication attempts in the following order:

1. `CustomProvider1`
2. `CustomProvider2`
3. `K8s.Conn.Auth.Certificate`
4. `K8s.Conn.Auth.Token`
5. `K8s.Conn.Auth.AuthProvider`
6. `K8s.Conn.Auth.Exec`
7. `K8s.Conn.Auth.BasicAuth`

For protocol and behavior implementation examples check out `K8s.Conn.Auth` implementations [here](https://github.com/coryodaniel/k8s/blob/develop/lib/k8s/conn/auth/).
