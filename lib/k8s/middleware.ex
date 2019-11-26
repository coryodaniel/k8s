# defmodule K8s.Middleware do
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
