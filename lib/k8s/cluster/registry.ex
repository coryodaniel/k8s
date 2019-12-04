defmodule K8s.Cluster.Registry do
  @moduledoc """
  Register resource definitions for `K8s.Cluster`
  """
  use GenServer
  alias K8s.Cluster.Discovery

  @five_minutes 5 * 60 * 1000
  @rediscover_interval Application.get_env(:k8s, :rediscover_interval, @five_minutes)

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    auto_register_clusters()
    schedule(@rediscover_interval)
    {:ok, %{}}
  end

  @doc """
  Add or update a cluster to use with `K8s.Client`

  ## Examples

      iex> conn = K8s.Conn.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.Registry.add(:test_cluster, conn)
      {:ok, :test_cluster}

  """
  @spec add(atom(), K8s.Conn.t()) :: {:ok, atom()} | {:error, atom()}
  def add(cluster, conn) do
    with true <- :ets.insert(K8s.Conn, {cluster, conn}),
         :ok <- K8s.Middleware.initialize(cluster),
         {:ok, resources_by_group} <- resources_by_group(cluster) do
      K8s.Cluster.Group.insert_all(cluster, resources_by_group)
      K8s.Sys.Event.cluster_registered(%{}, %{cluster: cluster})
      {:ok, cluster}
    end
  end

  @spec resources_by_group(atom(), Keyword.t() | nil) :: {:ok, map()} | {:error, atom()}
  def resources_by_group(cluster, opts \\ []) do
    K8s.refactor(__ENV__)
    {:ok, conn} = K8s.Cluster.conn(cluster)

    merged_opts = Keyword.merge(opts, conn.discovery_opts)
    {:ok, versions} = conn.discovery_driver.versions(conn, opts)

    r =
      Enum.reduce(versions, %{}, fn v, agg ->
        {:ok, resources} = conn.discovery_driver.resources(v, conn, opts)

        list = Map.get(agg, v, [])
        upd_list = list ++ resources
        Map.put(agg, v, upd_list)
      end)

    {:ok, r}
  end

  @doc """
  Registers clusters automatically from all configuration sources.

  See the [usage guide](https://hexdocs.pm/k8s/usage.html#registering-clusters) for more details on configuring connection details.

  ## Examples

  By default a cluster will attempt to use the ServiceAccount assigned to the pod:

  ```elixir
  config :k8s,
    clusters: %{
      default: %{}
    }
  ```

  Configuring a cluster using a k8s config:

  ```elixir
  config :k8s,
    clusters: %{
      default: %{
        conn: "~/.kube/config"
        conn_opts: [user: "some-user", cluster: "prod-cluster"]
      }
    }
  ```
  """
  @spec auto_register_clusters :: nil
  def auto_register_clusters do
    clusters = K8s.Config.clusters()

    Enum.each(clusters, fn {name, details} ->
      conn =
        case Map.get(details, :conn) do
          nil ->
            K8s.Conn.from_service_account()

          %{use_sa: true} ->
            K8s.Conn.from_service_account()

          conn_path ->
            opts = details[:conn_opts] || []
            K8s.Conn.from_file(conn_path, opts)
        end

      add(name, conn)
    end)

    nil
  end

  @doc false
  @impl GenServer
  @spec handle_info(:auto_register_clusters, Keyword.t()) :: {:noreply, Keyword.t()}
  def handle_info(:auto_register_clusters, state) do
    auto_register_clusters()
    schedule(@rediscover_interval)
    {:noreply, state}
  end

  @doc "Schedules a re-registration of all clusters."
  @spec schedule(pos_integer()) :: reference()
  def schedule(milliseconds) do
    Process.send_after(__MODULE__, :auto_register_clusters, milliseconds)
  end
end
