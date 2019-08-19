# credo:disable-for-this-file
defmodule K8s.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    :ets.new(K8s.Conn, [:set, :public, :named_table])
    :ets.new(K8s.Cluster.Group, [:set, :public, :named_table])
    K8s.Cluster.Registry.auto_register_clusters!()

    children = [{K8s.Cluster.Registry, []}]

    opts = [strategy: :one_for_one, name: K8s.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
