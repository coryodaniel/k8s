defmodule K8s.Client.Runner.Stream.ListRequest do
  @moduledoc "`:list` `K8s.Operation` encapsulated with pagination and `K8s.Conn`"
  @limit 10

  @typedoc "opts for `K8s.Client.Runner.Base.run/3`"
  @type opts_t :: keyword

  @typedoc "Pagination continue token"
  @type continue_t :: nil | :halt | binary

  @typedoc "List operation as a Stream data type"
  @type t :: %__MODULE__{
          operation: K8s.Operation.t(),
          conn: K8s.Conn.t(),
          continue: continue_t,
          limit: pos_integer,
          opts: opts_t
        }
  defstruct operation: nil, conn: nil, continue: nil, opts: [], limit: @limit

  @doc """
  Creates a `ListRequest` struct for the next HTTP request from the previous HTTP response
  """
  @spec make_next_request(t(), map | :halt) :: t()
  def make_next_request(%__MODULE__{} = request, response) do
    Map.put(request, :continue, maybe_continue(response))
  end

  @spec maybe_continue(map | :halt) :: continue_t()
  defp maybe_continue(%{"metadata" => %{"continue" => ""}}), do: :halt
  defp maybe_continue(%{"metadata" => %{"continue" => cont}}) when is_binary(cont), do: cont
  defp maybe_continue(_map), do: :halt
end
