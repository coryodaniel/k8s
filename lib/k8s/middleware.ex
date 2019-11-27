defmodule K8s.Middleware do
  @moduledoc "Interface for interacting with cluster middleware"

  @doc "Retrieve a list of middleware registered to a cluster"
  @spec list(:request | :response, atom()) :: list(module())
  def list(:request, _cluster) do
    [
      K8s.Middleware.Request.Initialize,
      K8s.Middleware.Request.EncodeBody
    ]
  end
end

# Agent should be in Middleware.Registry
#   use Agent

#   @doc """

#   """
#   @spec start_link(map) :: :ok
#   def start_link(%{} = middlwares) do
#     Agent.start_link(fn -> middlwares end, name: __MODULE__)
#   end

#   def list(cluster_name) do
#     Agent.get(__MODULE__, fn state -> Map.get(state, cluster_name, []) end)
#   end

#   def register(cluster_name, )

#   def value do
#     Agent.get(__MODULE__, & &1)
#   end

#   def increment do
#     Agent.update(__MODULE__, &(&1 + 1))
#   end
# end
