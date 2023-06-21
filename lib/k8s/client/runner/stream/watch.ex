defmodule K8s.Client.Runner.Stream.Watch do
  @moduledoc """
  Watches a `K8s.Client.list/3` operation and returns an Elixir [`Stream`](https://hexdocs.pm/elixir/Stream.html) of events.
  """

  alias K8s.Client.Runner.Base

  require Logger
  import K8s.Sys.Logger, only: [log_prefix: 1]

  @time_before_retry 5

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
      ...> K8s.Client.Runner.Watch.Stream.stream(conn, op, []) |> Stream.map(&IO.inspect/1) |> Stream.run()
  """
  @spec stream(K8s.Conn.t(), K8s.Operation.t(), keyword()) ::
          {:ok, Enumerable.t()} | K8s.Client.Provider.error_t()
  def stream(conn, operation, http_opts) do
    http_opts =
      http_opts
      |> Keyword.put_new(:params, [])
      |> put_in([:params, :allowWatchBookmarks], true)
      |> put_in([:params, :watch], 1)

    do_resource(conn, struct!(operation, verb: :list), http_opts, nil)
  end

  @spec do_resource(
          K8s.Conn.t(),
          K8s.Operation.t(),
          keyword(),
          nil | binary(),
          retries :: non_neg_integer()
        ) ::
          {:ok, Enumerable.t()} | K8s.Client.Provider.error_t()
  defp do_resource(conn, operation, http_opts, resource_version, retries \\ 0)

  defp do_resource(conn, operation, http_opts, nil, retries) do
    with {:ok, resource_version} <- get_resource_version(conn, operation) do
      do_resource(conn, operation, http_opts, resource_version, retries)
    end
  end

  defp do_resource(conn, operation, http_opts, resource_version, retries) do
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
    else
      error when retries > 0 ->
        Logger.warning(
          log_prefix(
            "Error when starting stream. Waiting #{@time_before_retry}s before retrying. #{retries} retries left."
          ),
          library: :k8s,
          error: error
        )

        Process.sleep(@time_before_retry * 1_000)
        do_resource(conn, operation, http_opts, resource_version, retries - 1)

      error ->
        Logger.warning(log_prefix("Error when starting stream."), library: :k8s, error: error)
        error
    end
  end

  @spec reduce(K8s.Client.Provider.http_chunk_t(), t() | :halt) ::
          {:halt, nil} | {Enumerable.t(), t()}
  defp reduce(_, :halt), do: {:halt, nil}

  defp reduce(:done, state) do
    Logger.debug(
      log_prefix("Watcher termineated the request. Starting a new watch request."),
      library: :k8s
    )

    {:ok, stream} =
      do_resource(state.conn, state.operation, state.http_opts, state.resource_version, 5)

    {stream, state}
  end

  defp reduce({:error, reason}, state) do
    Logger.warning(
      log_prefix(
        "Error #{inspect(reason)} received from the watcher. Waiting #{@time_before_retry} before restarting the watcher"
      ),
      library: :k8s
    )

    Process.sleep(@time_before_retry * 1_000)

    {:ok, stream} =
      do_resource(state.conn, state.operation, state.http_opts, state.resource_version, 5)

    {stream, state}
  end

  defp reduce({:status, 410}, state) do
    Logger.warning(
      log_prefix("410 Gone received from watcher - resetting the resource version"),
      library: :k8s
    )

    {:ok, stream} = do_resource(state.conn, state.operation, state.http_opts, nil)

    {stream, :halt}
  end

  defp reduce({:status, status}, _state) do
    Logger.warning(
      log_prefix("Erronous async status #{status} received from watcher - aborting the watch"),
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
      log_prefix("#{message} - resetting the resource version"),
      library: :k8s,
      object: object
    )

    new_state = struct!(state, resource_version: nil)
    {[], new_state}
  end

  defp process_object(%{"type" => "BOOKMARK", "object" => object}, state) do
    Logger.debug(
      log_prefix("Bookmark received"),
      library: :k8s,
      object: object
    )

    {[], struct!(state, resource_version: object["metadata"]["resourceVersion"])}
  end

  defp process_object(
         %{"object" => %{"metadata" => %{"resourceVersion" => resource_version}}},
         %{resource_version: resource_version} = state
       ) do
    # resource version already obeserved.
    {[], state}
  end

  defp process_object(%{"object" => %{"kind" => _} = object} = new_event, state) do
    # Emit new event
    new_state = struct!(state, resource_version: object["metadata"]["resourceVersion"])
    {[new_event], new_state}
  end

  defp process_object(%{"object" => %{"message" => message} = object}, state) do
    # Objects with only the "message" field but no "kind" are cosidered errors.
    Logger.error(
      log_prefix(
        "Erronous event received from watcher: #{message} - resetting the resource version"
      ),
      library: :k8s,
      object: object
    )

    new_state = struct!(state, resource_version: nil)
    {[], new_state}
  end

  @spec get_resource_version(K8s.Conn.t(), K8s.Operation.t()) :: {:ok, binary} | Base.error_t()
  defp get_resource_version(%K8s.Conn{} = conn, %K8s.Operation{} = operation) do
    with {:ok, payload} <- Base.run(conn, operation) do
      rv = parse_resource_version(payload)
      {:ok, rv}
    end
  end

  @resource_version_json_path ~w(metadata resourceVersion)
  @spec parse_resource_version(any) :: binary
  defp parse_resource_version(%{} = payload),
    do: get_in(payload, @resource_version_json_path) || "0"

  defp parse_resource_version(_), do: "0"
end
