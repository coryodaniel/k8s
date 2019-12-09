## Configuration

config :k8s,
  auth_providers: [],
  discovery_driver: K8s.Discovery.Driver.File,
  discovery_opts: [config: "test/support/discovery/example.json"],
  clusters: %{
    dev: %{
      conn: "~/.kube/config",
      conn_opts: [context: "docker-for-desktop"]
    },
    test: %{
      conn: "test/support/kube-config.yaml",
      conn_opts: [
        discovery_driver: K8s.Discovery.Driver.File,
        discovery_opts: [config: "test/support/discovery/example.json"]
      ]
    }
  }


config :k8s,
  discovery: %{
    driver: K8s.Discovery.Driver.File,
    opts: %{config: "test/support/discovery/example.json"}
  },
  conns: %{
    dev: %{
      config_path: "~/.kube/config",
      #service_account_path: "/var/run/..."
      #use_service_account: true,
      opts: %{
        context: "docker-for-desktop",
        discovery: %{
          driver: K8s.Discovery.Driver.HTTP,
          opts: %{cache: false}
        }
      }
    }
  }
