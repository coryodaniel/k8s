defmodule K8s.Middleware.Registry do
  @moduledoc "Cluster middleware registry"
  use Agent
  alias K8s.Middleware.Request

  @typedoc "List of middlewares"
  @type stack_t :: list(module())

  @spec start_link(Keyword.t()) :: Agent.on_start()
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @spec defaults(K8s.Middleware.type_t()) :: stack_t
  def defaults(:request), do: [Request.Initialize, Request.EncodeBody]
  def defaults(:response), do: []

  @doc "Adds a middleware to the end of the middleware stack"
  @spec add(atom, K8s.Middleware.type_t(), module()) :: :ok
  def add(cluster, type, middleware) do
    Agent.update(__MODULE__, fn registry ->
      cluster_middlewares = Map.get(registry, cluster, %{})
      middleware_list = Map.get(cluster_middlewares, type, defaults(type))

      updated_middleware_list = middleware_list ++ [middleware]
      updated_cluster_middlewares = Map.put(cluster_middlewares, type, updated_middleware_list)

      put_in(registry, [cluster], updated_cluster_middlewares)
    end)
  end

  @doc "Sets/replaces the middleware stack"
  @spec set(atom, K8s.Middleware.type_t(), list(module())) :: :ok
  def set(cluster, type, middlewares) do
    Agent.update(__MODULE__, fn registry ->
      cluster_middlewares = Map.get(registry, cluster, %{})
      updated_cluster_middlewares = Map.put(cluster_middlewares, type, middlewares)

      put_in(registry, [cluster], updated_cluster_middlewares)
    end)
  end

  @doc "Returns middleware stack for a cluster and (request or response)"
  @spec list(atom, K8s.Middleware.type_t()) :: K8s.Middleware.stack_t()
  def list(cluster, type) do
    registry = Agent.get(__MODULE__, & &1[cluster]) || %{}
    Map.get(registry, type, defaults(type))
  end
end
