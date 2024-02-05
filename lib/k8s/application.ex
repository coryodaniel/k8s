defmodule K8s.Application do
  @moduledoc false

  use Application
  @impl true
  def start(_type, _args) do
    children = [
      K8s.Client.Mint.ConnectionRegistry,
      {Registry, keys: :unique, name: K8s.Conn.Auth.Registry},
      {DynamicSupervisor, name: K8s.Client.Mint.ConnectionSupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: K8s.Conn.Auth.ProviderSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: K8s.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
