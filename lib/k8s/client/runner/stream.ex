defmodule K8s.Client.Runner.Stream do
  @moduledoc """
  Takes a `K8s.Client.list/3` operation and returns an Elixir [`Stream`](https://hexdocs.pm/elixir/Stream.html) of resources.
  """

  alias K8s.Client.Runner.Base
  alias K8s.Client.Runner.Stream.ListRequest
  alias K8s.Conn
  alias K8s.Operation

  @supported_operations [:list, :list_all_namespaces]

  @typedoc "List of items and pagination request"
  @type state_t :: {list(), ListRequest.t()}

  @typedoc "Halt streaming"
  @type halt_t :: {:halt, state_t}

  @doc """
  Validates operation type before calling `stream/3`. Only supports verbs: `list_all_namespaces` and `list`.
  """
  @spec run(Conn.t(), Operation.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, atom}
  def run(conn, op, http_opts \\ [])

  def run(%Conn{} = conn, %Operation{verb: verb} = op, http_opts)
      when verb in @supported_operations,
      do: {:ok, stream(conn, op, http_opts)}

  def run(_, _, _), do: {:error, :unsupported_operation}

  @doc """
  Returns an elixir stream of paginated list results.

  Elements in stream will be HTTP bodies, or error tuples.

  Encountering an HTTP error mid-stream will halt the stream.
  """
  @spec stream(Conn.t(), Operation.t(), keyword | nil) :: Enumerable.t()
  def stream(%Conn{} = conn, %Operation{} = op, http_opts \\ []) do
    request = %ListRequest{
      operation: op,
      conn: conn,
      http_opts: http_opts
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
  def next_item({[], _request} = state) do
    fetch_next_page(state)
  end

  # Items are in list, pop one and keep on keeping on.
  def next_item({_items, _request} = state) do
    pop_item(state)
  end

  @doc false
  # fetches next page when item list is empty. Returns `:halt` to stream processor when
  # maybe_continue returns `:halt`
  @spec fetch_next_page(state_t) :: state_t | halt_t
  def fetch_next_page({_empty, %ListRequest{continue: :halt}} = state) do
    {:halt, state}
  end

  def fetch_next_page({_empty, next_request} = _state) do
    next_request
    |> list
    |> pop_item
  end

  @doc false
  # Make a list request and convert response to stream state
  @spec list(ListRequest.t()) :: state_t
  def list(%ListRequest{operation: operation} = request) do
    query_params = operation.query_params || []
    pagination_params = [limit: request.limit, continue: request.continue]
    merged_params = Keyword.merge(query_params, pagination_params)
    updated_operation = %Operation{operation | query_params: merged_params}
    paginated_request = %ListRequest{request | operation: updated_operation}

    response =
      Base.run(
        paginated_request.conn,
        paginated_request.operation,
        paginated_request.http_opts
      )

    case response do
      {:ok, response} ->
        items = Map.get(response, "items", [])
        next_request = ListRequest.make_next_request(paginated_request, response)
        {items, next_request}

      {:error, error} ->
        items = [{:error, error}]
        halt_requests = ListRequest.make_next_request(paginated_request, :halt)
        {items, halt_requests}

      {:error, error, _info} ->
        items = [{:error, error}]
        halt_requests = ListRequest.make_next_request(paginated_request, :halt)
        {items, halt_requests}
    end
  end

  # Return the next item to the stream caller (`[head]`) and return the tail and next request as the current state
  @spec pop_item(state_t) :: {list, state_t}
  defp pop_item({[], next}) do
    new_state = {[], next}
    {[], new_state}
  end

  defp pop_item({[head | tail], next} = _state) do
    new_state = {tail, next}
    {[head], new_state}
  end

  @doc false
  # Stop processing the stream.
  @spec stop(state_t) :: nil
  def stop(_state) do
    nil
  end
end
