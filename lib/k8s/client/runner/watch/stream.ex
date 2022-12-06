defmodule K8s.Client.Runner.Watch.Stream do
  @moduledoc """
  Watches a `K8s.Client.list/3` operation and returns an Elixir [`Stream`](https://hexdocs.pm/elixir/Stream.html) of events.
  """

  alias K8s.Client.Runner.Base
  alias K8s.Client.Runner.Watch

  require Logger

  @log_prefix "#{__MODULE__} - " |> String.replace_leading("Elixir.", "")

  @type t :: %__MODULE__{
          conn: K8s.Conn.t(),
          operation: K8s.Operation.t(),
          resource_version: binary(),
          http_opts: keyword(),
          remainder: binary()
        }

  defstruct [:conn, :operation, :resource_version, :http_opts, remainder: ""]

  @doc """
  Watches resources and returns an Elixir Stream of events emmitted by kubernetes.

  ### Example

      iex> {:ok,conn} = K8s.Conn.from_file("~/.kube/config", [context: "docker-desktop"])
      ...> op = K8s.Client.list("v1", "Namespace")
      ...> K8s.Client.Runner.Watch.Stream.resource(conn, op, []) |> Stream.map(&IO.inspect/1) |> Stream.run()
  """
  @spec resource(K8s.Conn.t(), K8s.Operation.t(), keyword()) ::
          {:ok, Enumerable.t()} | K8s.Client.Provider.error_t()
  def resource(conn, operation, http_opts) do
    http_opts =
      http_opts
      |> Keyword.put_new(:params, [])
      |> put_in([:params, :allowWatchBookmarks], true)
      |> put_in([:params, :watch], true)
      |> Keyword.put(:async, :once)

    do_resource(conn, operation, http_opts, nil)
  end

  @spec do_resource(K8s.Conn.t(), K8s.Operation.t(), keyword(), nil | binary()) ::
          {:ok, Enumerable.t()} | K8s.Client.Provider.error_t()
  defp do_resource(conn, operation, http_opts, nil) do
    with {:ok, resource_version} <- Watch.get_resource_version(conn, operation) do
      do_resource(conn, operation, http_opts, resource_version)
    end
  end

  defp do_resource(conn, operation, http_opts, resource_version) do
    with http_opts <- put_in(http_opts, [:params, :resourceVersion], resource_version),
         {:ok, stream} <- Base.stream(conn, operation, http_opts) do
      stream =
        stream
        |> K8s.Client.HTTPStream.transform_to_lines()
        |> K8s.Client.HTTPStream.decode_json_objects()
        |> Stream.reject(&(&1 == {:status, 200}))
        |> Stream.filter(&(&1 == :done || elem(&1, 0) in [:status, :object, :error]))
        |> Stream.transform(
          %__MODULE__{
            conn: conn,
            operation: operation,
            http_opts: http_opts,
            resource_version: resource_version
          },
          &reduce/2
        )

      {:ok, stream}
    end
  end

  @spec reduce(K8s.Client.Provider.stream_chunk_t(), t() | :halt) ::
          {:halt, nil} | {Enumerable.t(), t()}
  defp reduce(_, :halt), do: {:halt, nil}

  defp reduce(:done, state) do
    {:ok, stream} =
      do_resource(state.conn, state.operation, state.http_opts, state.resource_version)

    {stream, state}
  end

  defp reduce({:status, 410}, state) do
    Logger.warn(
      @log_prefix <> "410 Gone received from watcher - resetting the resource version",
      library: :k8s
    )

    {:ok, stream} = do_resource(state.conn, state.operation, state.http_opts, nil)

    {stream, :halt}
  end

  defp reduce({:status, status}, _state) do
    Logger.warn(
      @log_prefix <> "Erronous async status #{status} received from watcher - aborting the watch",
      library: :k8s
    )

    {:halt, nil}
  end

  defp reduce({:object, object}, state) do
    process_object(object, state)
  end

  @spec process_object(map(), t()) :: {Enumerable.t(), t()}
  defp process_object(
         %{"type" => "ERROR", "object" => %{"message" => message, "code" => 410} = object},
         state
       ) do
    Logger.debug(
      @log_prefix <> "#{message} - resetting the resource version",
      library: :k8s,
      object: object
    )

    new_state = struct!(state, resource_version: nil)
    {[], new_state}
  end

  defp process_object(%{"object" => %{"message" => message} = object}, state) do
    Logger.error(
      @log_prefix <>
        "Erronous event received from watcher: #{message} - resetting the resource version",
      library: :k8s,
      object: object
    )

    new_state = struct!(state, resource_version: nil)
    {[], new_state}
  end

  defp process_object(%{"type" => "BOOKMARK", "object" => object}, state) do
    Logger.debug(
      @log_prefix <> "Bookmark received",
      library: :k8s,
      object: object
    )

    {[], struct!(state, resource_version: object["metadata"]["resourceVersion"])}
  end

  defp process_object(
         %{"object" => %{"metadata" => %{"resourceVersion" => resource_version}}},
         state
       )
       when resource_version == state.resource_version do
    {[], state}
  end

  defp process_object(%{"object" => object} = new_event, state) do
    new_state = struct!(state, resource_version: object["metadata"]["resourceVersion"])
    {[new_event], new_state}
  end
end
