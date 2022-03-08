import Config

config :k8s,
  discovery_driver: K8s.Discovery.Driver.File,
  discovery_opts: [config: "test/support/discovery/example.json"],
  http_provider: K8s.Client.DynamicHTTPProvider,
  ca_provider: CAStore
