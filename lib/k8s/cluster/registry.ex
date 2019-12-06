defmodule K8s.Cluster.Registry do
  @moduledoc """
  Register resource definitions for `K8s.Cluster`
  """
  use GenServer
  alias K8s.Cluster.Discovery

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @spec resources_by_group(atom(), Keyword.t() | nil) :: {:ok, map()} | {:error, atom()}
  def resources_by_group(cluster, opts \\ []) do
    K8s.refactor(__ENV__)

    {:ok, conn} = K8s.Conn.lookup(cluster)

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
end
