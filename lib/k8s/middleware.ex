defmodule K8s.Middleware do
  @moduledoc "Interface for interacting with cluster middleware"

  alias K8s.Middleware.{Error, Request}

  @doc "Retrieve a list of middleware registered to a cluster"
  @spec list(:request | :response, atom()) :: list(module())
  def list(:request, _cluster) do
    [
      Request.Initialize,
      Request.EncodeBody
    ]
  end

  @doc """
  Applies middlewares registered to a `K8s.Cluster` to a `K8s.Middleware.Request`
  """
  @spec run(Request.t()) :: {:ok, Request.t()} | {:error, Error.t()}
  def run(req) do
    middlewares = list(:request, req.cluster)

    result =
      Enum.reduce_while(middlewares, req, fn middleware, req ->
        case apply(middleware, :call, [req]) do
          {:ok, updated_request} ->
            {:cont, updated_request}

          {:error, error} ->
            {:halt, error(middleware, req, error)}
        end
      end)

    case result do
      %Request{} -> {:ok, result}
      %Error{} -> {:error, result}
    end
  end

  @spec error(module(), Request.t(), any()) :: Error.t()
  defp error(middleware, req, error) do
    %K8s.Middleware.Error{
      middleware: middleware,
      error: error,
      request: req
    }
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
