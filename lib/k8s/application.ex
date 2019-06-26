# credo:disable-for-this-file
defmodule K8s.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = []

    K8s.init()

    opts = [strategy: :one_for_one, name: K8s.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
