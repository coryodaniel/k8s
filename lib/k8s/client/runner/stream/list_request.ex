defmodule K8s.Client.Runner.Stream.ListRequest do
  @moduledoc "`:list` `K8s.Operation` encapsulated with pagination and `K8s.Conn`"

  alias K8s.Client.Runner.Base

  @limit 10
  @typedoc "Pagination continue token"
  @type continue_t :: nil | :halt | binary()

  @type responses_t :: map() | {:error, K8s.Client.HTTPError.t()}

  @typedoc "List operation as a Stream data type"
  @type t :: %__MODULE__{
          operation: K8s.Operation.t(),
          conn: K8s.Conn.t(),
          continue: continue_t,
          limit: pos_integer,
          http_opts: Keyword.t()
        }
  defstruct operation: nil, conn: nil, continue: nil, http_opts: [], limit: @limit

  @spec stream(K8s.Conn.t(), K8s.Operation.t(), Keyword.t()) :: Enumerable.t(responses_t)
  def stream(conn, op, http_opts) do
    Stream.resource(
      fn ->
        struct!(__MODULE__, operation: op, conn: conn, http_opts: http_opts)
      end,
      &next_item/1,
      &Function.identity/1
    )
  end

  @spec next_item(t()) :: {responses_t(), t()}
  def next_item(%__MODULE__{continue: :halt}), do: {:halt, nil}

  def next_item(state) do
    with {:ok, response} <-
           list(state.conn, state.operation, state.http_opts, state.limit, state.continue),
         cont <- maybe_continue(response),
         {:ok, items} <- Map.fetch(response, "items") do
      {items, struct!(state, continue: cont)}
    else
      :error ->
        {:halt, nil}

      {:error, error} ->
        {[{:error, error}], struct!(state, continue: :halt)}
    end
  end

  @spec list(K8s.Conn.t(), K8s.Operation.t(), Keyword.t(), integer(), continue_t()) ::
          K8s.Client.Provider.response_t()
  defp list(conn, op, http_opts, limit, continue) do
    new_params = [limit: limit, continue: continue]
    http_opts = Keyword.update(http_opts, :params, new_params, &Keyword.merge(&1, new_params))

    Base.run(conn, op, http_opts)
  end

  @spec maybe_continue(map | :halt) :: continue_t()
  defp maybe_continue(%{"metadata" => %{"continue" => ""}}), do: :halt

  defp maybe_continue(%{"metadata" => %{"continue" => cont}}) when is_binary(cont),
    do: cont

  defp maybe_continue(_map), do: :halt
end
