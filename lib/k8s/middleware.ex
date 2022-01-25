defmodule K8s.Middleware do
  @moduledoc """
  Interface for interacting with cluster middleware

  While middlewares are applied to `K8s.Middleware.Request`s they are registerd by a _cluster name_ which is an atom.

  This allows multiple connections to be used (different credentials) with the same middleware stack.

  Any cluster name that has _not_ been initialized, will automatically have the default stack applied.

  ## Examples
    Using default middleware
      iex> conn = %K8s.Conn{}
      ...> req = %K8s.Middlware.Request{}
      ...> K8s.Middleware.run(req)

    Adding middlware to a cluster
      iex> conn = %K8s.Conn{cluster_name: "foo"}
      ...> K8s.Middleware.add("foo", :request, MyMiddlewareModule)
      ...> req = %K8s.Middlware.Request{}
      ...> K8s.Middleware.run(req)

    Setting/Replacing middleware on a cluster
      iex> conn = %K8s.Conn{cluster_name: "foo"}
      ...> K8s.Middleware.set("foo", :request, [MyMiddlewareModule, OtherModule])
      ...> req = %K8s.Middlware.Request{}
      ...> K8s.Middleware.run(req)
  """

  alias K8s.Middleware.{Error, Request}

  @spec run(Request.t(), list(module())) :: {:ok, Request.t()} | {:error, Error.t()}
  def run(%Request{} = req, middlewares) do
    result =
      Enum.reduce_while(middlewares, req, fn middleware, req ->
        case middleware.call(req) do
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
  defp error(middleware, %Request{} = req, error) do
    %K8s.Middleware.Error{
      middleware: middleware,
      error: error,
      request: req
    }
  end
end
