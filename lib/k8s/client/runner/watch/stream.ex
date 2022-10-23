defmodule K8s.Client.Runner.Watch.Stream do
  @moduledoc """
  Watches a `K8s.Client.list/3` operation and returns an Elixir [`Stream`](https://hexdocs.pm/elixir/Stream.html) of events.
  """

  alias K8s.Client.Runner.Base
  alias K8s.Client.Runner.Watch

  require Logger

  @log_prefix "#{__MODULE__} - " |> String.replace_leading("Elixir.", "")

  @type t :: %__MODULE__{
          resp: HTTPoison.AsyncResponse.t(),
          conn: K8s.Conn.t(),
          operation: K8s.Operation.t(),
          resource_version: binary(),
          http_opts: keyword(),
          remainder: binary()
        }

  defstruct [:resp, :conn, :operation, :resource_version, :http_opts, remainder: ""]

  @doc """
  Watches resources and returns an Elixir Stream of events emmitted by kubernetes.

  ### Example

      iex> {:ok,conn} = K8s.Conn.from_file("~/.kube/config", [context: "docker-desktop"])
      ...> op = K8s.Client.list("v1", "Namespace")
      ...> K8s.Client.Runner.Watch.Stream.resource(conn, op, []) |> Stream.map(&IO.inspect/1) |> Stream.run()
  """
  @spec resource(K8s.Conn.t(), K8s.Operation.t(), keyword()) :: Enumerable.t() | {:error, any()}
  def resource(conn, operation, http_opts) do
    {:ok, resource_version} = Watch.get_resource_version(conn, operation)

    Stream.resource(
      fn ->
        {:start,
         %__MODULE__{
           conn: conn,
           operation: operation,
           http_opts: http_opts,
           resource_version: resource_version
         }}
      end,
      &next_fun/1,
      fn _state -> :ok end
    )
  end

  @docp """
  Producing the next elements in the stream.
  * If the accumulator is {:recv, state}, receives and processes events from the HTTPoison process
  * If the accumulator is {:start, state}, tries to make new HTTPoison watcher request (see below)
  """
  @spec next_fun({:recv, t()}) :: {[map()], {:recv | :start, t()}} | {:halt, nil}
  defp next_fun({:recv, %__MODULE__{} = state}) do
    receive do
      %HTTPoison.AsyncEnd{} ->
        Logger.debug(
          @log_prefix <> "AsyncEnd received - tryin to restart watcher",
          library: :k8s
        )

        {[], {:start, state}}

      %HTTPoison.AsyncHeaders{} ->
        HTTPoison.stream_next(state.resp)
        {[], {:recv, state}}

      %HTTPoison.AsyncStatus{code: 200} ->
        HTTPoison.stream_next(state.resp)
        {[], {:recv, state}}

      %HTTPoison.AsyncStatus{code: 410} ->
        Logger.warn(
          @log_prefix <> "410 Gone received from watcher - resetting the resource version",
          library: :k8s
        )

        new_state = struct!(state, resource_version: nil)
        {[], {:recv, new_state}}

      %HTTPoison.AsyncStatus{code: _} = error ->
        Logger.warn(
          @log_prefix <> "Erronous async status received from watcher - aborting the watch",
          library: :k8s,
          error: error
        )

        {:halt, nil}

      %HTTPoison.AsyncChunk{chunk: chunk} ->
        HTTPoison.stream_next(state.resp)

        {chunk, state}
        |> transform_to_lines()
        |> transform_to_events()

      %HTTPoison.Error{reason: {:closed, :timeout}} ->
        Logger.debug(
          @log_prefix <> "Watch request timed out - resuming the watch",
          library: :k8s
        )

        {[], {:start, state}}

      other ->
        Logger.debug(
          @log_prefix <> "Wacher received unexpected message.",
          library: :k8s,
          message: other
        )

        # ignore other messages and continue
        {[], {:recv, state}}
    end
  end

  @docp """
  Tries to make new HTTPoison watcher request (self-healing)
  """
  @spec next_fun({:start, map()}) :: {[map()], {:recv, t()}} | {:halt, nil}
  defp next_fun({:start, state}) do
    %{conn: conn, operation: operation, http_opts: http_opts} = state

    #  get latest resource version if it is missing in the state
    resource_version =
      case Map.get(state, :resource_version) do
        nil ->
          {:ok, resource_version} = Watch.get_resource_version(conn, operation)
          resource_version

        rv ->
          rv
      end

    #  prepare http_opts
    http_opts =
      http_opts
      |> Keyword.put_new(:params, [])
      |> put_in([:params, :resourceVersion], resource_version)
      |> put_in([:params, :allowWatchBookmarks], true)
      |> put_in([:params, :watch], true)
      |> Keyword.put(:stream_to, self())
      |> Keyword.put(:async, :once)

    #  start the watcher
    case Base.run(conn, operation, http_opts) do
      {:ok, ref} ->
        new_state =
          struct!(
            state,
            resp: %HTTPoison.AsyncResponse{id: ref},
            resource_version: resource_version
          )

        {[], {:recv, new_state}}

      error ->
        Logger.error(
          @log_prefix <> "Can't restart watcher - stopping watcher stream: #{inspect(error)}",
          library: :k8s
        )

        {:halt, nil}
    end
  end

  @docp """
  Transforms chunks to lines iteratively.

  Code is taken from https://elixirforum.com/t/streaming-lines-from-an-enum-of-chunks/21244/3

  * Append new chunk to the remainder inside state
  * Split resulting string by newlines (there can be multiple newlines in the new chunk)
  * pop the last element from the resulting list returns the remainder and the list of whole lines
  """
  @spec transform_to_lines({binary(), t()}) :: {[binary()], t()}
  defp transform_to_lines({chunk, state}) do
    {remainder, whole_lines} =
      (state.remainder <> chunk)
      |> String.split("\n")
      |> List.pop_at(-1)

    {whole_lines, %{state | remainder: remainder}}
  end

  @docp """
  Transform lines to events

  * decode JSON events
  * Reduce lines into events and next state
    * If the resource_version changes, append the event to the stream and update the state
    * Otherwise, dont change anything
    * send :start upon errors
  """
  @spec transform_to_events({[binary()], t()}) :: {[map()], {:recv | :start, t()}}
  defp transform_to_events({lines, state}) do
    lines
    #  decode errors handled below
    |> Enum.map(&Jason.decode/1)
    |> Enum.reduce({[], {:recv, state}}, fn
      _, {events, {:start, state}} ->
        {events, {:start, state}}

      {:error, error}, {events, acc} ->
        Logger.error(
          @log_prefix <> "Could not decode JSON - chunk seems to be malformed",
          library: :k8s,
          error: error
        )

        {events, acc}

      {:ok, %{"type" => "ERROR", "object" => %{"message" => message, "code" => 410} = object}},
      {events, {_, state}} ->
        Logger.debug(
          @log_prefix <> "#{message} - resetting the resource version",
          library: :k8s,
          object: object
        )

        new_state = struct!(state, resource_version: nil)
        {events, {:recv, new_state}}

      {:ok, %{"object" => %{"message" => message} = object}}, {events, {_, state}} ->
        Logger.error(
          @log_prefix <>
            "Erronous event received from watcher: #{message} - resetting the resource version",
          library: :k8s,
          object: object
        )

        new_state = struct!(state, resource_version: nil)
        {events, {:recv, new_state}}

      {:ok, %{"type" => "BOOKMARK", "object" => object}}, {events, {:recv, state}} ->
        Logger.debug(
          @log_prefix <> "Bookmark received",
          library: :k8s,
          object: object
        )

        {events,
         {:recv, %__MODULE__{state | resource_version: object["metadata"]["resourceVersion"]}}}

      {:ok, %{"object" => %{"metadata" => %{"resourceVersion" => new_resource_version}}}},
      {events, {:recv, %__MODULE__{resource_version: resource_version} = state}}
      when new_resource_version == resource_version ->
        {events, {:recv, state}}

      {:ok, %{"object" => object} = new_event}, {events, {:recv, state}} ->
        # new resource_version => append new event to the stream
        {events ++ [new_event],
         {:recv, %__MODULE__{state | resource_version: object["metadata"]["resourceVersion"]}}}
    end)
  end
end
