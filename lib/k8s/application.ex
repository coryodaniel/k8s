# credo:disable-for-this-file
defmodule K8s.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    :ets.new(K8s.Conn, [:set, :public, :named_table])
    :ets.new(K8s.Cluster.Group, [:set, :public, :named_table])

    # TODO: register defaults for each cluster
    children = [
      {K8s.Middleware.Registry, []},
      {K8s.Cluster.Registry, []}
    ]

    opts = [strategy: :one_for_one, name: K8s.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
