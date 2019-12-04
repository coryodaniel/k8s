defmodule K8s.Discovery do
  @doc """
  Override the _default_ driver for discovery.

  Each `K8s.Conn` can have its own driver set. If unset, this value will be used.

  Defaults to `K8s.Discovery.Driver.HTTP`

  ## Example mix config
  In the example below `dev` and `test` clusters will use the File driver, while `prod` will use the HTTP driver.
  ```elixir
  use Mix.Config

  config :k8s,
    discovery_driver: K8s.Discovery.Driver.File,
    discovery_opts: [config: "test/support/discovery/example.json"],

    clusters: %{
      test: %{
        conn: "test/support/kube-config.yaml"
      },
      dev: %{
        conn: "test/support/kube-config.yaml"
      },
      prod: %{
        conn: "test/support/kube-config.yaml",
        conn_opts: [
          discovery_driver: K8s.Discovery.Driver.HTTP
        ]
      }
    }
  ```
  """
  @spec default_driver() :: module()
  def default_driver do
    Application.get_env(:k8s, :discovery_driver, K8s.Discovery.Driver.HTTP)
  end

  @doc """
  Override default opts for the discovery driver. This is also configurable per `K8s.Conn`
  """
  @spec default_opts() :: Keyword.t()
  def default_opts do
    Application.get_env(:k8s, :discovery_opts, [])
  end
end
