defmodule K8s do
  @moduledoc "Kubernetes API Client for Elixir"

  @doc false
  @spec http_provider() :: module()
  def http_provider do
    Application.get_env(:k8s, :http_provider, K8s.Client.HTTPProvider)
  end

  def refactor(e) do
    {name, arity} = e.function
    IO.puts("TODO: Remove #{e.module}.#{name}/#{arity}")
  end
end
