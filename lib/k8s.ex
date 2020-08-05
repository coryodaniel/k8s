defmodule K8s do
  @moduledoc "Kubernetes API Client for Elixir"

  @doc false
  @spec http_provider() :: module()
  @deprecated "Call K8s.default_http_provider/0 instead"
  def http_provider, do: default_http_provider()

  @doc "Returns the default HTTP Provider"
  @spec default_http_provider() :: module()
  def default_http_provider do
    Application.get_env(:k8s, :http_provider, K8s.Client.HTTPProvider)
  end

  @doc """
  Returns the _default_ driver for discovery.

  Each `K8s.Conn` can have its own driver set. If unset, this value will be used.

  Defaults to `K8s.Discovery.Driver.HTTP`

  ## Example mix config
  In the example below `dev` and `test` clusters will use the File driver, while `prod` will use the HTTP driver.

  Cluster names can be atoms or strings, but are internally stored as strings.

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
  @spec default_discovery_driver() :: module()
  def default_discovery_driver do
    Application.get_env(:k8s, :discovery_driver, K8s.Discovery.Driver.HTTP)
  end

  @doc """
  Returns default opts for the discovery driver. This is also configurable per `K8s.Conn`
  """
  @spec default_discovery_opts() :: Keyword.t()
  def default_discovery_opts do
    Application.get_env(:k8s, :discovery_opts, [])
  end
end
