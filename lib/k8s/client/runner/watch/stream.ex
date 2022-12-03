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
          Enumerable.t() | {:error, any()}
  def resource(conn, operation, http_opts) do
    http_opts =
      http_opts
      |> Keyword.put_new(:params, [])
      |> put_in([:params, :allowWatchBookmarks], true)
      |> put_in([:params, :watch], true)
      |> Keyword.put(:async, :once)

    do_resource(conn, operation, http_opts, nil)
  end

  defp do_resource(conn, operation, http_opts, nil) do
    {:ok, resource_version} = Watch.get_resource_version(conn, operation)
    do_resource(conn, operation, http_opts, resource_version)
  end

  defp do_resource(conn, operation, http_opts, resource_version) do
    http_opts = put_in(http_opts, [:params, :resourceVersion], resource_version)

    Base.stream(conn, operation, http_opts)
    |> Stream.reject(&(&1 == {:status, 200}))
    |> Stream.filter(&(elem(&1, 0) in [:status, :data, :error]))
    |> Stream.transform(
      fn ->
        %__MODULE__{
          conn: conn,
          operation: operation,
          http_opts: http_opts,
          resource_version: resource_version
        }
      end,
      &reduce/2,
      fn
        nil ->
          {:halt, nil}

        state ->
          {do_resource(state.conn, state.operation, state.http_opts, state.resource_version),
           state}
      end,
      fn _state -> :ok end
    )
  end

  defp reduce(_, :halt), do: {:halt, nil}

  defp reduce({:status, 410}, state) do
    Logger.warn(
      @log_prefix <> "410 Gone received from watcher - resetting the resource version",
      library: :k8s
    )

    new_state = struct!(state, resource_version: nil)
    {[], new_state}
  end

  defp reduce({:status, status}, _state) do
    Logger.warn(
      @log_prefix <> "Erronous async status #{status} received from watcher - aborting the watch",
      library: :k8s
    )

    {:halt, nil}
  end

  defp reduce({:data, chunk}, state) do
    {chunk, state}
    |> transform_to_lines()
    |> transform_to_events()
  end

  defp reduce({:error, {:closed, :timeout}}, state) do
    Logger.debug(
      @log_prefix <> "Watch request timed out - resuming the watch",
      library: :k8s
    )

    {do_resource(state.conn, state.operation, state.http_opts, state.resource_version), :halt}
  end

  # Transforms chunks to lines iteratively.

  # Code is taken from https://elixirforum.com/t/streaming-lines-from-an-enum-of-chunks/21244/3

  # * Append new chunk to the remainder inside state
  # * Split resulting string by newlines (there can be multiple newlines in the new chunk)
  # * pop the last element from the resulting list returns the remainder and the list of whole lines
  @spec transform_to_lines({binary(), t()}) :: {[binary()], t()}
  defp transform_to_lines({chunk, state}) do
    {remainder, whole_lines} =
      (state.remainder <> chunk)
      |> String.split("\n")
      |> List.pop_at(-1)

    {whole_lines, %{state | remainder: remainder}}
  end

  # Transform lines to events
  # * decode JSON events
  # * Reduce lines into events and next state
  #   * If the resource_version changes, append the event to the stream and update the state
  #   * Otherwise, dont change anything
  #   * send :start upon errors
  @spec transform_to_events({[binary()], t()}) :: {[map()], {:recv | :start, t()}}
  defp transform_to_events({lines, state}) do
    lines
    #  decode errors handled below
    |> Enum.map(&Jason.decode/1)
    |> Enum.reduce({[], state}, fn
      {:error, error}, {events, state} ->
        Logger.error(
          @log_prefix <> "Could not decode JSON - chunk seems to be malformed",
          library: :k8s,
          error: error
        )

        {events, state}

      {:ok, %{"type" => "ERROR", "object" => %{"message" => message, "code" => 410} = object}},
      {events, state} ->
        Logger.debug(
          @log_prefix <> "#{message} - resetting the resource version",
          library: :k8s,
          object: object
        )

        new_state = struct!(state, resource_version: nil)
        {events, new_state}

      {:ok, %{"object" => %{"message" => message} = object}}, {events, state} ->
        Logger.error(
          @log_prefix <>
            "Erronous event received from watcher: #{message} - resetting the resource version",
          library: :k8s,
          object: object
        )

        new_state = struct!(state, resource_version: nil)
        {events, new_state}

      {:ok, %{"type" => "BOOKMARK", "object" => object}}, {events, state} ->
        Logger.debug(
          @log_prefix <> "Bookmark received",
          library: :k8s,
          object: object
        )

        {events, %__MODULE__{state | resource_version: object["metadata"]["resourceVersion"]}}

      {:ok, %{"object" => %{"metadata" => %{"resourceVersion" => new_resource_version}}}},
      {events, %__MODULE__{resource_version: resource_version} = state}
      when new_resource_version == resource_version ->
        {events, state}

      {:ok, %{"object" => object} = new_event}, {events, state} ->
        # new resource_version => append new event to the stream
        {events ++ [new_event],
         struct!(state, resource_version: object["metadata"]["resourceVersion"])}
    end)
  end
end
