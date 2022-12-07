defmodule K8s.Client.Runner.Stream do
  @moduledoc """
  Takes a `K8s.Client.list/3` operation and returns an Elixir [`Stream`](https://hexdocs.pm/elixir/Stream.html) of resources.
  """

  alias K8s.Client.Runner.Base
  alias K8s.Client.Runner.Stream.ListRequest
  alias K8s.Conn
  alias K8s.Operation
  alias K8s.Operation.Error

  @supported_operations [:list, :list_all_namespaces]

  @typedoc "List of items and pagination request"
  @type state_t :: {list(), ListRequest.t()}

  @typedoc "Halt streaming"
  @type halt_t :: {:halt, state_t}

  @doc """
  Validates operation type before calling `stream/3`. Only supports verbs: `list_all_namespaces` and `list`.
  """
  @spec run(Conn.t(), Operation.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def run(conn, op, http_opts \\ [])

  def run(%Conn{} = conn, %Operation{verb: verb} = op, http_opts)
      when verb in [:list, :list_all_namespaces],
      do: {:ok, ListRequest.stream(conn, op, http_opts)}

  def run(op, _, _) do
    msg = "Only #{inspect(@supported_operations)} operations can be streamed. #{inspect(op)}"

    {:error, %Error{message: msg}}
  end
end
