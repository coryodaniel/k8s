use Mix.Config

config :k8s,
  discovery_driver: K8s.Discovery.Driver.File,
  discovery_opts: [config: "test/support/discovery/example.json"],
  http_provider: K8s.Client.DynamicHTTPProvider,
  clusters: %{
    "test" => %{
      conn: "test/support/kube-config.yaml",
      conn_opts: [
        discovery_driver: K8s.Discovery.Driver.File,
        discovery_opts: [config: "test/support/discovery/example.json"]
      ]
    }
  },
  cluster_connections: %{
    "test" => %{
      auth: "file://test/support/kube-config.yaml"
    }
  }
