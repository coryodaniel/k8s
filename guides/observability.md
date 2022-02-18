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

Tracing has not been implemented yet.