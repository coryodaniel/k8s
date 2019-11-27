defmodule K8s.Middleware.Error do
  @moduledoc "Encapsulates middleware process errors"

  @typedoc """
  Middleware processing error

  * `middleware` middleware module that caused the error
  * `request` `K8s.Middleware.Request`
  * `error` actual error, can be `any()` type
  """
  @type t :: %__MODULE__{
          request: K8s.Middleware.Request.t() | nil,
          middleware: module(),
          error: any()
        }
  defstruct [:request, :middleware, :error]
end
