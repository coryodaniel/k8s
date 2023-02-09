defmodule K8s.Client.Mint.HTTPAdapter do
  @moduledoc """
  The Mint client implementation. This module handles both, HTTP requests and
  websocket connections.

  ## Processes

  The module creates a process per connection to the Kubernetes API server.
  It supports `HTTP/2` for HTTP requests, but not for websockets. So while
  an open connection can process multiple requests (if the server supports
  `HTTP/2`), it can only process one single websocket connection.
  Therefore, each websocket connection is handled in its own process.

  ## State

  The module keeps track of the `Mint.HTTP` connection struct and a map of
  pending requests (`K8s.Client.Mint.Request`) for that connection, indexed by the
  `Mint.Types.request_ref()`.

  ### Requests

  Requests are calls to the GenServer that immediately return while the GenServer
  receives the response parts in the background. The way these response parts are
  returned depends on the `state_to` argument passed to `request/7` resp.
  `websocket_request/5`. See these function's docs for more details.
  """
  use GenServer, restart: :temporary

  alias K8s.Client.HTTPError
  alias K8s.Client.Mint.Request

  require Logger
  require Mint.HTTP

  @type connection_args_t ::
          {scheme :: atom(), host :: binary(), port :: integer(), opts :: keyword()}

  @typedoc """
  Describes the state of the connection.

  - `:conn` - The current state of the `Mint` connection.
  - `:requests` - The opened requests over this connection (Only `HTTP/2` connections will hold multiple entries in this field.)
  """
  @type t :: %__MODULE__{
          conn: Mint.HTTP.t(),
          requests: %{reference() => Request.t()}
        }

  defstruct [:conn, requests: %{}]

  @doc """
  Opens a connection to Kubernetes, defined by `uri` and `opts`,
  and starts the GenServer.
  """
  @spec start_link(connection_args_t()) :: GenServer.on_start()
  def start_link(conn_args) do
    GenServer.start_link(__MODULE__, conn_args)
  end

  @doc """
  Returns connection arguments for the given `URI` and HTTP options.
  """
  @spec connection_args(URI.t(), keyword()) :: connection_args_t()
  def connection_args(uri, opts) do
    {String.to_atom(uri.scheme), uri.host, uri.port, opts}
  end

  @doc """
  Starts a HTTP request. The way the response parts are returned depends on the
  `stream_to` argument passed to it.

    - `nil` - response parts are buffered. In order to receive them, the caller
      needs to `recv/2` passing it the `request_ref` returned by this function.
    - `pid` - response parts are sent to the process with the given `pid`.
    - `{pid, reference}` - response parts are sent to the process with the given
      `pid`. Messages are of the form `{reference, response_part}`.
  """
  @spec request(
          GenServer.server(),
          method :: binary(),
          path :: binary(),
          Mint.Types.headers(),
          body :: iodata() | nil | :stream,
          pool :: pid() | nil,
          stream_to :: pid() | nil
        ) :: {:ok, reference()} | {:error, HTTPError.t()}
  def request(pid, method, path, headers, body, pool, stream_to) do
    GenServer.call(pid, {:request, method, path, headers, body, pool, stream_to})
  end

  @doc """
  Upgrades to a Websocket connection. The way the frames are returned depends
  on the `stream_to` argument passed to it.

    - `nil` - frames are buffered. In order to receive them, the caller
      needs to `recv/2` passing it the `request_ref` returned by this function.
    - `pid` - frames are sent to the process with the given `pid`.
    - `{pid, reference}` - frames are sent to the process with the given
      `pid`. Messages are of the form `{reference, response_part}`.
  """
  @spec websocket_request(
          pid(),
          path :: binary(),
          Mint.Types.headers(),
          pool :: pid() | nil,
          stream_to :: pid() | nil
        ) :: {:ok, reference()} | {:error, HTTPError.t()}
  def websocket_request(pid, path, headers, pool, stream_to) do
    GenServer.call(pid, {:websocket_request, path, headers, pool, stream_to})
  end

  @doc """
  Returns response parts / frames that were buffered by the process. The
  `stream_to` must have been set to `nil` in `request/7` or
  `websocket_request/5`.

  If the buffer is empty, this call blocks until the next response part /
  frame is received.
  """
  @spec recv(GenServer.server(), reference()) :: list()
  def recv(pid, ref) do
    GenServer.call(pid, {:recv, ref}, :infinity)
  end

  @doc """
  Sends the given `data` throught the websocket specified by the `request_ref`.
  """
  @spec websocket_send(
          GenServer.server(),
          reference(),
          term()
        ) :: :ok
  def websocket_send(pid, request_ref, data) do
    GenServer.cast(pid, {:websocket_send, request_ref, data})
  end

  @impl true
  def init({scheme, host, port, opts}) do
    case Mint.HTTP.connect(scheme, host, port, opts) do
      {:ok, conn} ->
        state = %__MODULE__{conn: conn}
        {:ok, state}

      {:error, error} ->
        Logger.error("Failed initializing HTTPAdapter GenServer", library: :k8s)
        {:stop, HTTPError.from_exception(error)}
    end
  end

  @impl true
  def handle_call({:request, method, path, headers, body, pool, stream_to}, from, state) do
    caller_ref = from |> elem(0) |> Process.monitor()

    # stream body if there is one.
    {body, pending_request_body} =
      case body do
        nil -> {body, body}
        body -> {:stream, String.to_charlist(body)}
      end

    with {:ok, conn, request_ref} <- Mint.HTTP.request(state.conn, method, path, headers, body),
         {:request, request} <-
           {:request,
            Request.new(
              request_ref: request_ref,
              pool: pool,
              stream_to: stream_to,
              caller_ref: caller_ref,
              pending_request_body: pending_request_body
            )},
         {:ok, request, conn} <- Request.stream_request_body(request, conn) do
      state = put_in(state.requests[request_ref], request) |> struct!(conn: conn)
      {:reply, {:ok, request_ref}, state}
    else
      {:error, conn, error} ->
        state = struct!(state, conn: conn)

        {:reply, {:error, HTTPError.from_exception(error)}, state}
    end
  end

  def handle_call({:websocket_request, path, headers, pool, stream_to}, from, state) do
    caller_ref = from |> elem(0) |> Process.monitor()

    with {:ok, conn} <- Mint.HTTP.set_mode(state.conn, :passive),
         {:ok, conn, request_ref} <- Mint.WebSocket.upgrade(:wss, conn, path, headers),
         {:ok, conn, response} <- Request.receive_upgrade_response(conn, request_ref),
         {:ok, conn} <- Mint.HTTP.set_mode(conn, :active),
         {:ok, conn, websocket} <-
           Mint.WebSocket.new(conn, request_ref, response.status, response.headers) do
      state =
        put_in(
          state.requests[request_ref],
          Request.new(
            request_ref: request_ref,
            websocket: websocket,
            pool: pool,
            stream_to: stream_to,
            caller_ref: caller_ref
          )
        )

      send(stream_to, {:open, true})
      {:reply, {:ok, request_ref}, struct!(state, conn: conn)}
    else
      {:error, error} ->
        GenServer.reply(from, {:error, HTTPError.from_exception(error)})
        {:stop, :normal, state}

      {:error, conn, error} ->
        GenServer.reply(from, {:error, HTTPError.from_exception(error)})
        {:stop, :normal, struct!(state, conn: conn)}
    end
  end

  def handle_call({:recv, request_ref}, from, state) do
    case get_and_update_in(
           state.requests[request_ref],
           &Request.recv(&1, from)
         ) do
      {:stop, state} ->
        {:stop, :normal, state}

      {_, state} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:websocket_send, request_ref, data}, state) do
    request = state.requests[request_ref]

    with {:ok, frame} <- Request.map_outgoing_frame(data),
         {:ok, websocket, data} <- Mint.WebSocket.encode(request.websocket, frame),
         {:ok, conn} <- Mint.WebSocket.stream_request_body(state.conn, request_ref, data) do
      state = struct!(state, conn: conn)
      state = put_in(state.requests[request_ref].websocket, websocket)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(message, %__MODULE__{conn: conn} = state)
      when Mint.HTTP.is_connection_message(conn, message) do
    with {:ok, conn, responses} <- Mint.WebSocket.stream(state.conn, message),
         {:ok, state} <- stream_pending_request_bodies(struct!(state, conn: conn)) do
      process_responses_or_frames(state, responses)
    else
      {:error, conn, %Mint.TransportError{reason: :closed}, []} ->
        Logger.debug("The connection was closed.", library: :k8s)

        # We could terminate the process here. But there might still be chunks
        # in the buffer, so we don't.
        {:noreply, struct!(state, conn: conn)}

      {:error, conn, error} ->
        Logger.error(
          "An error occurred when streaming the request body: #{Exception.message(error)}",
          error: error,
          library: :k8s
        )

        struct!(state, conn: conn)

      {:error, conn, error, responses} ->
        Logger.error("An error occurred when streaming the response: #{Exception.message(error)}",
          error: error,
          library: :k8s
        )

        state
        |> struct!(conn: conn)
        |> process_responses_or_frames(responses)
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    state =
      state.requests
      |> Map.filter(fn {_request_ref, request} -> request.caller_ref == ref end)
      |> Map.keys()
      |> Enum.reduce_while(state, fn
        request_ref, state ->
          case pop_in(state.requests[request_ref]) do
            {%Request{}, %{conn: %Mint.HTTP2{}} = state} ->
              conn = Mint.HTTP2.cancel_request(state.conn, request_ref) |> elem(1)
              {:cont, struct!(state, conn: conn)}

            {_, state} ->
              {:halt, {:stop, state}}
          end
      end)

    case state do
      {:stop, state} ->
        Logger.debug(
          "Received :DOWN signal from parent process. Terminating HTTPAdapter #{inspect(self())}.",
          library: :k8s
        )

        {:stop, :normal, state}

      state ->
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    state = state

    state.requests
    |> Enum.filter(fn {_ref, request} -> !is_nil(request.websocket) end)
    |> Enum.each(fn {request_ref, request} ->
      {:ok, _websocket, data} = Mint.WebSocket.encode(request.websocket, :close)
      Mint.WebSocket.stream_request_body(state.conn, request_ref, data)
    end)

    Mint.HTTP.close(state.conn)
    Logger.debug("Terminating HTTPAdapter GenServer #{inspect(self())}", library: :k8s)
    :ok
  end

  @spec stream_pending_request_bodies(t()) ::
          {:ok, t()} | {:error, Mint.HTTP.t(), Mint.Types.error()}
  defp stream_pending_request_bodies(state) do
    stream_pending_request_bodies(state, Map.values(state.requests))
  end

  @spec stream_pending_request_bodies(t(), [Request.t()]) ::
          {:ok, t()} | {:error, Mint.HTTP.t(), Mint.Types.error()}
  defp stream_pending_request_bodies(state, []) do
    {:ok, state}
  end

  defp stream_pending_request_bodies(state, [request | rest]) do
    case Request.stream_request_body(
           request,
           state.conn
         ) do
      {:ok, request, conn} ->
        state =
          put_in(state.requests[request.request_ref], request)
          |> struct!(conn: conn)

        stream_pending_request_bodies(state, rest)

      {:error, conn, error} ->
        {:error, conn, error}
    end
  end

  @spec process_responses_or_frames(t(), [Mint.Types.response()]) :: {:noreply, t()}
  defp process_responses_or_frames(state, [{:data, request_ref, data}] = responses) do
    request = state.requests[request_ref]

    if is_nil(request.websocket) do
      process_responses(state, responses)
    else
      {:ok, websocket, frames} = Mint.WebSocket.decode(request.websocket, data)
      state = put_in(state.requests[request_ref].websocket, websocket)
      process_frames(state, request_ref, frames)
    end
  end

  defp process_responses_or_frames(state, responses) do
    process_responses(state, responses)
  end

  @spec process_frames(t(), reference(), list(Mint.WebSocket.frame())) :: {:noreply, t()}
  defp process_frames(state, request_ref, frames) do
    state =
      frames
      |> Enum.map(&Request.map_frame/1)
      |> Enum.reduce_while(state, fn mapped_frame, state ->
        case get_and_update_in(
               state.requests[request_ref],
               &Request.put_response(&1, mapped_frame)
             ) do
          {:stop, state} ->
            # StreamTo requests need to be stopped from inside the GenServer.
            {:halt, {:stop, :normal, state}}

          {_, state} ->
            {:cont, state}
        end
      end)

    case state do
      {:stop, :normal, state} -> {:stop, :normal, state}
      state -> {:noreply, state}
    end
  end

  @spec process_responses(t(), [Mint.Types.response()]) :: {:noreply, t()}
  defp process_responses(state, responses) do
    state =
      responses
      |> Enum.map(&Request.map_response/1)
      |> Enum.reduce(state, fn {mapped_response, request_ref}, state ->
        {_, state} =
          get_and_update_in(
            state.requests[request_ref],
            &Request.put_response(&1, mapped_response)
          )

        state
      end)

    {:noreply, state}
  end
end
