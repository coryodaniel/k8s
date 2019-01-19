defmodule K8s.Cluster do
  @moduledoc """
  Cluster should support start_link ... so people can include it in their application directly?
  Router encapsulates config, so base.ex build_http_req/ needs to lose Conf


  GenServer state is conf, name spec
  on init creates agent, stores ref in state
  creates ETS table

  conf = K8s.Conf.from_file("...")
  K8s.Cluster.new conf: conf, name: name, spec: "spec.json"
  cluster = K8s.Cluster.start (adds to dynamic)
  operation = K8s.Client.get(deployment)

  K8s.Client.run(operation, cluster: :default)
  """

  @doc """
  Defines a new cluster and places it under `K8s.ClusterSupervisor`.

  You may also use `start_link/1` to link it to a different supervision tree.
  """
  use GenServer

  @typedoc "Cluster configuration"
  @type t :: %{
    name: atom,
    agent_pid: pid,
    conf: K8s.Conf.t() | binary() | nil,
    spec: binary
  }
  defstruct [:name, :agent_pid, :conf, :spec]

  ## Client

  @spec new() :: DynamicSupervisor.on_start_child()
  def new() do
    opts = %{
      name: :default,
      spec: "./priv/swagger/1.13.json",
      conf: "./test/support/kube-config.yaml"
    }

    DynamicSupervisor.start_child(K8s.ClusterSupervisor, child_spec(opts))
  end

  @doc false
  @spec child_spec(map) :: map
  def child_spec(opts) do
    %{
      id: K8s.Cluster,
      start: {__MODULE__, :start_link, [opts]},
      shutdown: 5_000,
      restart: :transient,
      type: :worker
    }
  end

  def info(cluster) do
    GenServer.call(cluster_id(cluster), :info)
  end

  @doc """
  """
  @spec start_link(map) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: cluster_id(opts.name))
  end

  ## Server

  @impl true
  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:conf, _from, state) do

    {:reply, state, state}
  end

  @impl true
  @spec init(map) :: {:ok, __MODULE__.t()}
  def init(opts) do
    # @@HERE: Skip agent, use genserver state, move router into cluster/
    state =
      __MODULE__
      |> struct(opts)
      |> Map.put(:agent_pid, agent_pid)

    {:ok, state}
  end


  ## Private

  defp load_config(conf = %K8s.Conf{}), do: conf
  defp load_config(conf), do: K8s.Conf.load(conf)

  defp cluster_id(name \\ :default), do: String.to_atom("#{__MODULE__}.#{name}")
end
