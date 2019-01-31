use Mix.Config

config :k8s,
  discovery_provider: Mock.Discovery,
  http_provider: Mock.HTTPProvider,
  clusters: %{
    test: %{
      conf: "test/support/kube-config.yaml"
    }
  }
