# Migrations

## Migrating from `< 2.0.0`

With version `2.0.0` some breaking changes were introduced in order to stabilize
the library. Most of them are in the `watch` and `stream` functionalities.
If you're using `K8s.Client.DynamicHTTPProvider` in your tests, you
will have to change your mocks slightly.

### DynamicHTTPProvider

The spec for `K8s.Client.Provider.request/N` and `K8s.Client.Provider.stream/N`
were changed which reflects in your mock implementation if you're using
`K8s.Client.DynamicHTTPProvider`. Concretely, the second variable is now of type
`%URI{}` and contains the path and query_params.

#### Migrating the path

In most of the cases you're probably matching against the path that's passed
to the function. In this case, you can just wrap the path by the struct:

**Old:**

```elixir
  defmodule K8sMock do
    def request(:get, "/api/v1/namespaces", _body, _headers, _opts) do
      # code
    end
  end
```

**New:**

```elixir
  defmodule K8sMock do
    def request(:get, %URI{path: "/api/v1/namespaces"}, _body, _headers, _opts) do
      # code
    end
  end
```

#### Migrating the query parameters

If you're matching against query parameters sent to the function, you will
have to match them in the `URI` as well:

**Old:**

```elixir
  defmodule K8sMock do
    def request(:get, "/api/v1/namespaces", _body, _headers, params: [labelSelector: "app=nginx"]) do
      # code
    end
  end
```

**New:**

```elixir
  defmodule K8sMock do
    def request(:get, %URI{path: "/api/v1/namespaces", query: "labelSelector=app%3Dnginx"}, _body, _headers, _opts) do
      # code
    end
  end
```

### Watch and Stream

`K8s.Client.watch/N` was used to run a `:list` operation and watch it. With this
release, there is now a `:watch` operation. `K8s.Client.watch/N` now is used
to create a `:watch` operation which has to be passed to `K8s.Client.stream/N`.
Also, the `stream_to` option was removed. See below.

### Streaming to another process - The `stream_to` option was removed

Before `2.0.0`, you could pass the `stream_to` option to stream packets to a
process. With the migration from HTTPoison to Mint, this option was removed.
For `:connect` operations, `K8s.Client.stream_to/N` can be used as a replacement.
Other operations will have to be streamed using `K8s.Client.stream/N` or go over
`K8s.Client.Runner.Base.stream_to/N`.

#### Examples

```elixir
:ok =
  K8s.Client.watch("v1", "ConfigMap", namespace: "default")
  |> K8s.Client.put_conn(conn)
  |> K8s.Client.Runner.Base.stream_to(self())

receive do
  event -> IO.inspect(event)
end
```

Pass a `{pid, reference}` tuple to get scoped messages:

```elixir
ref = make_ref()
:ok =
  K8s.Client.watch("v1", "ConfigMap", namespace: "default")
  |> K8s.Client.put_conn(conn)
  |> K8s.Client.Runner.Base.stream_to({self(), ref})

receive do
  {^ref, event} -> IO.inspect(event)
end
```


### Local Clusters and TLS Hostname Verification

Local clusters are usually accessed via IP address so the hostname provided by
the TLS certificate can't match the actual hostname (IP address). While somehow
HTTPoison was OK with this, Mint declines the HTTPS connection. In order to make
this work, you have to disable TLS peer verification. See also issue
[#203](https://github.com/coryodaniel/k8s/issues/203)

```elixir
{:ok, conn} = K8s.Conn.from_file(...)
conn = struct!(conn, insecure_skip_tls_verify: true)
```

### HTTPoison was removed

Wherever you match against `HTTPoison.*`, you're gonna have to change your code.
This might be the case in your error handlers. With `2.0.0`, all HTTP errors are
wrapped in a `K8s.Client.HTTPError` exception struct.

```

```
