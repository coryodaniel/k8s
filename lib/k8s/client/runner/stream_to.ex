defmodule K8s.Client.Runner.StreamTo do
  @moduledoc """
  Takes a `K8s.Client.list/3` operation and returns an Elixir [`Stream`](https://hexdocs.pm/elixir/Stream.html) of resources.
  """
  alias K8s.Client.Provider
  alias K8s.Client.Runner.Base
  alias K8s.Conn
  alias K8s.Operation
  alias K8s.Operation.Error

  @supported_operations [:connect]

  @doc """
  Validates operation type before calling `stream/3`. Only supports verbs: `list_all_namespaces` and `list`.
  """
  @spec run(Operation.t(), stream_to :: pid()) :: Provider.stream_to_response_t()
  def run(%Operation{conn: %Conn{} = conn} = op, stream_to), do: run(conn, op, [], stream_to)

  @spec run(Operation.t(), keyword(), stream_to :: pid()) ::
          Provider.stream_to_response_t()
  def run(%Operation{conn: %Conn{} = conn} = op, http_opts, stream_to),
    do: run(conn, op, http_opts, stream_to)

  @spec run(Conn.t(), Operation.t(), stream_to :: pid()) ::
          Provider.stream_to_response_t()
  def run(%Conn{} = conn, %Operation{} = op, stream_to), do: run(conn, op, [], stream_to)

  @spec run(Conn.t(), Operation.t(), keyword(), stream_to :: pid()) ::
          Provider.stream_to_response_t()
  def run(%Conn{} = conn, %Operation{verb: :connect} = op, http_opts, stream_to) do
    Base.stream_to(conn, op, http_opts, stream_to)
  end

  def run(op, _, _, _) do
    msg = "Only #{inspect(@supported_operations)} operations can be streamed. #{inspect(op)}"

    {:error, %Error{message: msg}}
  end
end
