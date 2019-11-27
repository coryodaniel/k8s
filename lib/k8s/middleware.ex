defmodule K8s.Middleware do
  @moduledoc "Interface for interacting with cluster middleware"

  alias K8s.Middleware.{Error, Request}

  @typedoc "Middleware type"
  @type type_t :: :request | :response

  @typedoc "List of middlewares"
  @type stack_t :: list(module())

  @spec defaults(K8s.Middleware.type_t()) :: stack_t
  def defaults(:request) do
    [
      Request.Initialize,
      Request.EncodeBody
    ]
  end

  @doc "Retrieve a list of middleware registered to a cluster"
  @spec list(type_t, atom()) :: stack_t
  def list(:request, _cluster) do
    # TODO interact w/ registry
    defaults(:request)
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
