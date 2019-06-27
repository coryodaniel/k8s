defmodule K8s.Client.Runner.Stream do
  @moduledoc """
  Takes a `K8s.Client.list/3` operation and returns an Elixir [`Stream`](https://hexdocs.pm/elixir/Stream.html)
  """

  defmodule ListRequest do
    @moduledoc "List operation as a Stream data type"
    @limit 10

    @typedoc "opts for `Base.run/3`"
    @type opts_t :: keyword | nil

    @typedoc "List operation as a Stream data type"
    @type t :: %{
            operation: K8s.Operation.t(),
            cluster: atom,
            continue: nil | binary | :halt,
            limit: pos_integer,
            opts: opts_t
          }
    defstruct operation: nil, cluster: nil, continue: nil, opts: [], limit: @limit
  end

  alias K8s.Client.Runner.Base
  alias K8s.Operation
  alias K8s.Client.Runner.Stream.ListRequest

  @typedoc "List of items and pagination request"
  @type state_t :: {list(), nil | ListRequest.t()}

  @typedoc "Halt streaming"
  @type halt_t :: {:halt, state_t}

  @typedoc "Success / Error"
  @type return_t :: {:ok, Enumerable.t()} | {:error, atom}

  @doc """
  Validates operation type before calling `stream/3`. Only supports verbs: `list_all_namespaces` and `list`.
  """
  @spec run(Operation.t(), atom, keyword()) :: return_t
  def run(operation, cluster, opts \\ [])

  def run(%Operation{verb: :list_all_namespaces} = op, cluster, opts),
    do: {:ok, stream(op, cluster, opts)}

  def run(%Operation{verb: :list} = op, cluster, opts), do: {:ok, stream(op, cluster, opts)}

  def run(_, _, _), do: {:error, :unsupported_operation}

  @doc """
  Returns an elixir stream of paginated list results.
  """
  @spec stream(Operation.t(), atom, keyword | nil) :: Enumerable.t()
  def stream(%Operation{} = op, cluster, opts \\ []) do
    request = %ListRequest{
      operation: op,
      cluster: cluster,
      opts: opts
    }

    Stream.resource(
      fn -> {[], request} end,
      &next_item/1,
      &stop/1
    )
  end

  @doc false
  @spec next_item(state_t) :: state_t | halt_t
  # All items in list have been popped, get more
  def next_item({[], _request} = state), do: fetch_next_page(state)

  # Items are in list, pop one and keep on keeping on.
  def next_item(state), do: pop_item(state)

  @doc false
  # fetches next page when item list is empty. Returns `:halt` to stream processor when
  # maybe_continue returns `:halt`
  @spec fetch_next_page(state_t) :: state_t | halt_t

  def fetch_next_page({_, %ListRequest{continue: :halt}} = state), do: {:halt, state}

  def fetch_next_page({[], next_request} = _state) do
    case list(next_request) do
      {:ok, state} ->
        pop_item(state)

      {:halt, state} ->
        {:halt, state}
    end
  end

  @doc false
  # Make a list request and convert response to stream state
  @spec list(ListRequest.t()) :: {:ok, state_t} | {:error, atom()}
  def list(%ListRequest{} = request) do
    default_params = request.opts[:params] || %{}
    pagination_params = %{limit: request.limit, continue: request.continue}
    request_params = Map.merge(default_params || %{}, pagination_params)
    opts = Keyword.put(request.opts, :params, request_params)

    response = Base.run(request.operation, request.cluster, opts)

    case response do
      {:ok, response} ->
        items = Map.get(response, "items")
        next_request = make_next_request(request, response)
        {:ok, {items, next_request}}

      {:error, error} ->
        items = [{:error, error}]
        next_request = make_next_request(request, :halt)
        {:ok, {items, next_request}}
    end
  end

  @spec make_next_request(ListRequest.t(), map) :: ListRequest.t()
  defp make_next_request(%ListRequest{} = request, response) do
    Map.put(request, :continue, maybe_continue(response))
  end

  @spec maybe_continue(map) :: :halt | binary
  defp maybe_continue(%{"metadata" => %{"continue" => ""}}), do: :halt
  defp maybe_continue(%{"metadata" => %{"continue" => cont}}) when is_binary(cont), do: cont
  defp maybe_continue(_map), do: :halt

  # Return the next item to the stream caller `[head]` and return the tail as the new state of the Stream
  @spec pop_item(state_t) :: state_t
  defp pop_item({[head | tail], next}) do
    new_state = {tail, next}
    {[head], new_state}
  end

  @doc false
  # Stop processing the stream.
  @spec stop(state_t) :: nil
  def stop(_state), do: nil
end
