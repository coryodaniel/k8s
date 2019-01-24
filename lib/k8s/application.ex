defmodule K8s.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = []

    K8s.init()

    opts = [strategy: :one_for_one, name: K8s.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
