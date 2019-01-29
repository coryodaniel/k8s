use Mix.Config

config :k8s,
  discovery_provider: Mock.Discovery,
  clusters: %{
    test: %{
      conf: "test/support/kube-config.yaml"
    }
  }
