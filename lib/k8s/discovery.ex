defmodule K8s.Discovery do
  @moduledoc "Kubernetes API Discovery"
  alias K8s.{Conn, Operation}

  @behaviour K8s.Discovery.Driver

  @impl true
  def resources(api_version, %K8s.Conn{discovery_driver: driver} = conn, opts \\ []) do
    driver.resources(api_version, conn, opts)
  end

  @impl true
  def versions(%K8s.Conn{discovery_driver: driver} = conn, opts \\ []) do
    driver.versions(conn, opts)
  end

  @doc """
  Discovery the URL for a `K8s.Conn` and `K8s.Operation`

  ## Examples

      iex> conn = K8s.Conn.from_file("./test/support/kube-config.yaml")
      ...> op = K8s.Operation.build(:get, "apps/v1", :deployments, [namespace: "default", name: "nginx"])
      ...> K8s.Discovery.url_for(conn, op)
      {:ok, "https://localhost:6443/apis/apps/v1/namespaces/default/deployments/nginx"}

  """
  @spec url_for(Conn.t(), Operation.t()) :: {:ok, String.t()} | {:error, atom(), binary()}
  def url_for(%Conn{} = conn, %Operation{api_version: api_version, name: name, verb: _} = op) do
    with {:ok, name} <-
           K8s.Discovery.ResourceFinder.resource_name_for_kind(conn, api_version, name),
         op <- Map.put(op, :name, name),
         {:ok, path} <- Operation.to_path(op) do
      {:ok, Path.join(conn.url, path)}
    end
  end

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
      "test" => %{
        conn: "test/support/kube-config.yaml"
      },
      "dev" => %{
        conn: "test/support/kube-config.yaml"
      },
      "prod" => %{
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
