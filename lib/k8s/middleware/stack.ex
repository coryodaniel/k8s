defmodule K8s.Middleware.Stack do
  @moduledoc "`K8s.Middlware` stacks to apply to a `K8s.Conn`"
  alias K8s.Middleware.Request
  defstruct [:request, :response]

  @type t :: %__MODULE__{
          request: list(module),
          response: list(module)
        }

  @doc "The default middleware stack"
  @spec default :: t
  def default,
    do: %__MODULE__{
      request: [Request.Initialize, Request.EncodeBody],
      response: []
    }
end
