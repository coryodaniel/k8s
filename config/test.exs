use Mix.Config

config :k8s,
  discovery_driver: K8s.Cluster.Discovery.FileDriver,
  discovery_opts: %{
    api_versions_path: "test/support/discovery/sample_api_versions.json",
    resource_definitions_path: "test/support/discovery/resource_definitions.json"
  },
  http_provider: K8s.Client.DynamicHTTPProvider,
  clusters: %{
    test: %{
      conn: "test/support/kube-config.yaml"
    }
  }
