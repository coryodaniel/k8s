defmodule K8s.Client.Runner.Stream do
  @moduledoc """
  Takes a `K8s.Client.list/3` operation and returns an Elixir [`Stream`](https://hexdocs.pm/elixir/Stream.html) of resources.
  """
  alias K8s.Client.Runner.Base
  alias K8s.Client.Runner.Stream.ListRequest
  alias K8s.Client.Runner.Stream.Watch
  alias K8s.Conn
  alias K8s.Operation
  alias K8s.Operation.Error

  @supported_operations [:list, :list_all_namespaces, :watch, :watch_all_namespaces, :connect]

  @doc """
  Validates operation type before calling `stream/3`. Only supports verbs: `list_all_namespaces` and `list`.
  """
  @spec run(Operation.t()) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def run(%Operation{conn: %Conn{} = conn} = op), do: run(conn, op, [])

  @spec run(Operation.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def run(%Operation{conn: %Conn{} = conn} = op, http_opts), do: run(conn, op, http_opts)

  @spec run(Conn.t(), Operation.t()) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def run(%Conn{} = conn, %Operation{} = op), do: run(conn, op, [])

  @spec run(Conn.t(), Operation.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def run(%Conn{} = conn, %Operation{verb: verb} = op, http_opts)
      when verb in [:list, :list_all_namespaces] do
    op = name_as_field_selector(op)
    {:ok, ListRequest.stream(conn, op, http_opts)}
  end

  def run(%Conn{} = conn, %Operation{verb: verb} = op, http_opts)
      when verb in [:watch, :watch_all_namespaces] do
    op = name_as_field_selector(op)
    Watch.stream(conn, op, http_opts)
  end

  def run(%Conn{} = conn, %Operation{verb: :connect} = op, http_opts) do
    Base.stream(conn, op, http_opts)
  end

  def run(op, _, _) do
    msg = "Only #{inspect(@supported_operations)} operations can be streamed. #{inspect(op)}"

    {:error, %Error{message: msg}}
  end

  @spec name_as_field_selector(Operation.t()) :: Operation.t()
  defp name_as_field_selector(operation) do
    {name, operation} = pop_in(operation, [Access.key(:path_params), :name])

    if is_nil(name), do: operation, else: K8s.Selector.field(operation, {"metadata.name", name})
  end
end
