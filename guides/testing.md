# Testing

`k8s` supports a few mechanisms to stub Kubernetes HTTP requests when developing or testing locally.

## Mocking API Version and Resource Discovery

`K8s` does resource discovery of the Kubernetes API before running `K8s.Operation`s. When testing if a Kubernetes cluster isn't available you can use the module `K8s.Discovery.Driver.File` to stub Kubernetes `api-resource` and `api-versions` responses.

The mock used in the test suite is [here](./test/support/discovery/example.json).

The driver can be set for all clusters or per-cluster:

```elixir
config :k8s,
  discovery_driver: K8s.Discovery.Driver.File,
  discovery_opts: [config: "test/support/discovery/example.json"],
  clusters: %{
    test: %{
      conn: "test/support/kube-config.yaml",
      conn_opts: [
        discovery_driver: K8s.Discovery.Driver.File,
        discovery_opts: [config: "test/support/discovery/example.json"]
      ]
    }
  }
```

## Mocking HTTP Responses of `K8s.Operations` in your application

`K8s` ships with a [`K8s.Client.DynamicHTTPProvider`](./lib/k8s/client/dynamic_http_provider.ex) for stubbing HTTP responses to kubernetes API requests.

This provider is used throughout the test suite for mocking HTTP responses.

To enable the dynamic HTTP provider it must be turned on in your `config.exs`:

```elixir
config :k8s, http_provider: K8s.Client.DynamicHTTPProvider
```

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
    assert {:ok, namespaces} = K8s.Client.run(conn, operation)
    assert namespaces == [%{"metadata" => %{"name" => "default"}}]
  end
end
```

To see advanced examples of usage, check out these examples in the test suite:

* [client/runner/base](./test/k8s/client/runner/base_test.exs)
* [client/runner/stream](./test/k8s/client/runner/stream_test.exs)
* [client/runner/watch](./test/k8s/client/runner/watch_test.exs)
* [discovery](./test/k8s/discovery_test.exs)
  