# Observability 

## Logging

All logs produced by this library should have `library: :k8s` as metadata which can be used in filters. 
`K8s.Sys.Logger` watches all telemetry events and logs them with `:measurements` and `:metadata` 
metadata entries which can be used in structured logs. In order to use it, you have to attach its 
telemetry handler. Call `K8s.Sys.Logger.attach/0` in your `application.ex`:

```elixir
K8s.Sys.Logger.attach()
```

## Telemetry

`K8s.Sys.Telemetry` provides a list of events _executed_ by this library. Use it to attach handlers to
them. 

## Tracing

There are two connectors to `:telemetry` spans/events. 

### OpenTelemetry

If you're [OpenTelemetry](https://opentelemetry.io/docs/instrumentation/erlang/), attach 
`:telemetry` spans/events to the OpenTelemetry handler:

```elixir
K8s.Sys.OpenTelemetry.attach()
```

### Spandex


If you're using a [Spandex](https://github.com/spandex-project/spandex) tracer, Attach 
`:telemetry` spans/events to the Spandex handler. Pass the tracer you created according
to the Spandex documentation as argument to the `attach/1` function.

```elixir
K8s.Sys.Spandex.attach(MyApp.Tracer)
```