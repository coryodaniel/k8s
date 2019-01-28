use Mix.Config
config :k8s,
  api_provider: Mock.API,
  clusters: %{
    test: %{
      conf: "test/support/kube-config.yaml"
    }
  }
