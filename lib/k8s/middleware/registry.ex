defmodule K8s.Middleware.Registry do
  @moduledoc """
  Cluster middleware registry
  """
  use Agent

  @spec start_link(map()) :: :ok
  def start_link(registry = %{}) do
    Agent.start_link(fn -> registry end, name: __MODULE__)
  end

  @doc "Adds a middleware to the end of the middleware stack"
  @spec add(atom, :request | :response, module()) :: :ok
  def add(cluster, type, middleware) do
  end

  @doc "Sets/replaces the middleware stack"
  @spec set(atom, :request | :response, list(module())) :: :ok
  def set(cluster, type, middlewares) do
  end
end
