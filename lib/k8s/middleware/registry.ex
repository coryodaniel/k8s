defmodule K8s.Middleware.Registry do
  @moduledoc "Cluster middleware registry"
  use Agent

  @spec start_link(Keyword.t()) :: Agent.on_start()
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc "Adds a middleware to the end of the middleware stack"
  @spec add(atom, :request | :response, module()) :: :ok
  def add(cluster, type, middleware) do
    Agent.update(__MODULE__, fn registry ->
      cluster_middlewares = Map.get(registry, cluster, %{})
      middleware_list = Map.get(cluster_middlewares, type, [])

      updated_middleware_list = middleware_list ++ [middleware]
      updated_cluster_middlewares = Map.put(cluster_middlewares, type, updated_middleware_list)

      put_in(registry, [cluster], updated_cluster_middlewares)
    end)
  end

  @doc "Sets/replaces the middleware stack"
  @spec set(atom, :request | :response, list(module())) :: :ok
  def set(cluster, type, middlewares) do
    Agent.update(__MODULE__, fn registry ->
      cluster_middlewares = Map.get(registry, cluster, %{})
      updated_cluster_middlewares = Map.put(cluster_middlewares, type, middlewares)

      put_in(registry, [cluster], updated_cluster_middlewares)
    end)
  end

  @doc "Returns middleware stack for a cluster and (request or response)"
  @spec list(atom, :request | :response) :: :ok
  def list(cluster, type) do
    registry = Agent.get(__MODULE__, & &1[cluster]) || %{}
    Map.get(registry, type, [])
  end
end
