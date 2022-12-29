# Migrations

## Migrating from `< 2.0.0`

With version `2.0.0` some breaking changes were introduced in order to stabilize
the library. Most of them are in the `watch` and `stream` functionalities.
If you're using `K8s.Client.DynamicHTTPProvider` in your tests, you
will have to change your mocks slightly.

### DynamicHTTPProvider

The spec for `K8s.Client.Provider.request/5` and `K8s.Client.Provider.stream/5`
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
As a replacement, `K8s.Client.stream_to/N` was added. Use this function instest
but note that the chunks that are sent to the receiving process come in different
form now.

#### Example

```elixir
:ok =
  K8s.Client.watch("v1", "ConfigMap", namespace: "default")
  |> K8s.Client.put_conn(conn)
  |> K8s.Client.stream_to(self())

receive do
  event -> IO.inspect(event)
end
```

### HTTPoison was removed

Wherever you match against `HTTPoison.*`, you're gonna have to change your code.
This might be the case in your error handlers. With `2.0.0`, all HTTP errors are
wrapped in a `K8s.Client.HTTPError` exception struct.
