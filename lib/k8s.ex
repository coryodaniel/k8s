defmodule K8s do
  @moduledoc """
  Kubernetes API Client for Elixir
  """

  @doc false
  @spec http_provider() :: module()
  def http_provider do
    Application.get_env(:k8s, :http_provider, K8s.Client.HTTPProvider)
  end

  @doc false
  @spec default_driver() :: module()
  def default_driver do
    config = Application.get_env(:k8s, :discovery, %{})
    Map.get(config, :driver, K8s.Discovery.Driver.HTTP)
  end

  @doc false
  @spec default_driver_opts() :: Keyword.t()
  def default_driver_opts do
    config = Application.get_env(:k8s, :discovery, %{})
    Map.get(config, :opts, [])
  end

  def refactor(e) do
    {name, arity} = e.function
    IO.puts("TODO: Refactored out, remove. #{e.module}.#{name}/#{arity}")
  end
end
