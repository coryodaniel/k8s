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

      iex> conf = K8s.Conn.from_file("./test/support/kube-config.yaml")
      ...> K8s.Cluster.Registry.add(:test_cluster, conf)
      {:ok, :test_cluster}

  """
  @spec add(atom(), K8s.Conn.t()) :: {:ok, atom()} | {:error, atom()}
  def add(cluster, conf) do
    with true <- :ets.insert(K8s.Conn, {cluster, conf}),
         {:ok, resources_by_group} <- Discovery.resources_by_group(cluster) do
      K8s.Cluster.Group.insert_all(cluster, resources_by_group)
      K8s.Sys.Event.cluster_registered(%{}, %{cluster: cluster})
      {:ok, cluster}
    end
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
        conf: "~/.kube/config"
        conf_opts: [user: "some-user", cluster: "prod-cluster"]
      }
    }
  ```
  """
  @spec auto_register_clusters :: nil
  def auto_register_clusters do
    clusters = K8s.Config.clusters()

    Enum.each(clusters, fn {name, details} ->
      conf =
        case Map.get(details, :conf) do
          nil ->
            K8s.Conn.from_service_account()

          %{use_sa: true} ->
            K8s.Conn.from_service_account()

          conf_path ->
            opts = details[:conf_opts] || []
            K8s.Conn.from_file(conf_path, opts)
        end

      add(name, conf)
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
