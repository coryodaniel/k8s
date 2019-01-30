use Mix.Config

config :k8s,
  auth_providers: [],
  clusters: %{
    dev: %{
      conf: "test/support/kube-config.yaml"
    }
  }
