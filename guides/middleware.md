# Middleware

`K8s.Middleware` is registered by connection name. By default a few pieces of middleware are registered for all connections.

* `K8s.Middleware.Request.Initialize`
* `K8s.Middleware.Request.EncodeBody`

## Request Middleware

Middleware can be added to a connection or the entire middleware stack can be replaced.

### Adding Request Middleware

Given a registered `K8s.Conn` named `:foo` the following example will add `ExampleMiddleware` to the end of the middleware stack

```elixir
K8s.Middleware.Registry.add(:foo, :request, MyMiddlewareModule)
```

### Replacing the Middleware Stack

Given a registered `K8s.Conn` named `:foo` the following example will replace the middleware stack.

```elixir
K8s.Middleware.Registry.set(:foo, :request, [MyMiddlewareModule])
```

### Listing Middleware for a `K8s.Conn`

```elixir
K8s.Middleware.Registry.list(:foo, :request)
[K8s.Middleware.Request.Initialize, K8s.Middleware.Request.EncodeBody]
```

### Writing Request Middleware

`K8s.Middleware.Request` is a behaviour and struct for encapsulating requests processed by the middleware stack. Middleware is expected to return `{:ok, %Request{}}` to continue processing or `{:error, :my_error}` to halt. The error in the error tuple can be an atom or a struct. It will automatically be wrapped in `K8s.Middleware.Error` during processing.

To implement a piece of middleware, you need to define a function `call/1` that accepts a `K8s.Middleware.Request`.

The example below will automatically add labels to a `:post` requests.

```elixir
def call(%Request{method: :post, body: body} = req) do
  metadata = Map.get(body, "metadata", %{})
  metadata_with_labels = Map.put(metadata, "labels", %{"env" => "prod"})
  updated_body = Map.put(body, "metadata", metadata_with_labels)

  request_with_labels = %Request{req | body: updated_body}
  {:ok, request_with_labels}
end
```

## Response Middleware

Response middleware has not been implemented at this time.
