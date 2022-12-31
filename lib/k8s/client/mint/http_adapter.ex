defmodule K8s.Client.Mint.HTTPAdapter do
  @moduledoc """
  The Mint client implementation. This module handles both, HTTP requests and
  websocket connections and offers 3 functions for each: `request/5`, `stream/5`
  and `stream_to/6` or respecively `websocket_request/3`, `websocket_stream/3`
  and `websocket_stream_to/4`.

  ## Processes

  The module creates a process per connection to the Kubernetes API server.
  It supports `HTTP/2` for HTTP requests, but not for websockets. So while
  an open connection can process multiple `HTTP/2` requests, it can only
  process one single websocket connection. Therefore, each websocket
  connection is handled in its own process. For `HTTP/2` requests, the module
  `K8s.Client.Mint.ConnectionRegistry` serves as registry to open connections
  and register them.

  ## State

  The module keeps track of the `Mint.HTTP` connection struct and a map of
  pending requests for that connection, indexed by the
  `Mint.Types.request_ref()`. Depending on the type of the request, the
  tracked request is either one of three structs:

  * `K8s.Client.Mint.Request` - for `HTTP/2` requests
  * `K8s.Client.Mint.UpgradeRequest` - for websocket upgrade requests
  * `K8s.Client.Mint.WebSocketRequest` - open websocket connections

  Besides some type specific fields, all of these structs maintain a `response`
  field which is a map of response parts, indexed by type of the part (e.g.
  `:headers`, `:status`, `:data`). In the case of websockets, the incoming
  chunks are parsed and split by channel, so the type  will e `:stdout`,
  `:stderr`, `:error`.

  ## Request Types

  As mentioned above, there's three ways to make a request.

  ### Requests - `request/5` and `websocket_request/3`

  Requests are synchronous (blocking) calls to the GenServer. It's not until
  the requeset is `:done` resp. the websocket is closed that the GenServer
  will reply with the complete request's response map.

  ### Streams - `stream/5` and `websocket_stream/3`

  These functions immediately return an [Elixir Stream](https://hexdocs.pm/elixir/Stream.html).
  Running the stream blocks until response parts are received and streams
  them thereafter.

  ### StreamTo - `stream_to/6`and `websocket_stream_to/4`

  These functions take an extra `stream_to` argument and return a
  `{:ok, send_to_websocket}` tuple. They stream the response parts to the
  process defined by `stream_to`. `send_to_websocket` is a function and serves
  as a way to send data through the websocket back to Kubernetes.
  """
  use GenServer, restart: :temporary

  alias K8s.Client.{HTTPError, Provider}
  alias K8s.Client.Mint.Request.HTTP, as: HTTPRequest
  alias K8s.Client.Mint.Request.Upgrade, as: UpgradeRequest
  alias K8s.Client.Mint.Request.WebSocket, as: WebSocketRequest

  require Logger
  require Mint.HTTP

  defstruct [:conn, requests: %{}]

  @type connection_args_t ::
          {scheme :: atom(), host :: binary(), port :: integer(), opts :: keyword()}
  @type t :: %__MODULE__{}

  @doc """
  Opens a connection to Kubernetes, defined by `uri` and `opts`,
  and starts the GenServer.
  """
  @spec start_link({URI.t(), keyword()}) :: GenServer.on_start()
  def start_link({uri, opts}) do
    start_link(connection_args(uri, opts))
  end

  @spec start_link(connection_args_t()) :: GenServer.on_start()
  def start_link(connection_args) do
    GenServer.start_link(__MODULE__, connection_args)
  end

  @spec connection_args(URI.t(), keyword()) :: connection_args_t()
  def connection_args(uri, opts) do
    {String.to_atom(uri.scheme), uri.host, uri.port, opts}
  end

  @doc """
  Makes a synchronous HTTP request to the server.
  """
  @spec request(
          pid(),
          method :: binary(),
          path :: binary(),
          Mint.Types.headers(),
          body :: iodata() | nil | :stream
        ) :: Provider.response_t()
  def request(pid, method, path, headers, body) do
    GenServer.call(pid, {:request, method, path, headers, body}, 30_000)
  end

  @doc """
  Same as `request/5` but returns a stream of response chunks.
  """
  @spec stream(
          pid(),
          method :: binary(),
          path :: binary(),
          Mint.Types.headers(),
          body :: iodata() | nil | :stream
        ) :: Provider.stream_response_t()
  def stream(pid, method, path, headers, body) do
    with {:ok, request_ref} <- GenServer.call(pid, {:stream, method, path, headers, body}) do
      stream =
        Stream.resource(
          fn -> request_ref end,
          fn
            {:halt, request_ref} ->
              {:halt, request_ref}

            request_ref ->
              case GenServer.call(pid, {:next_buffer, request_ref}, :infinity) do
                {:cont, data} -> {data, request_ref}
                {:halt, data} -> {data, {:halt, request_ref}}
              end
          end,
          fn request_ref ->
            GenServer.cast(pid, {:terminate_request, request_ref})
          end
        )

      {:ok, stream}
    end
  end

  @doc """
  Same as `request/5` but streams the response chunks to the process
  defined by `stream_to`
  """
  @spec stream_to(
          pid(),
          method :: binary(),
          path :: binary(),
          Mint.Types.headers(),
          body :: iodata() | nil | :stream,
          stream_to :: pid()
        ) :: Provider.stream_to_response_t()
  def stream_to(pid, method, path, headers, body, stream_to) do
    GenServer.call(pid, {:stream_to, method, path, headers, body, stream_to})
  end

  @doc """
  Upgrades the connection to a websocket and waits for the other end to close it.
  Once it is closed, all the received chunks are returned as a map.
  """
  @spec websocket_request(
          pid(),
          path :: binary(),
          Mint.Types.headers()
        ) :: Provider.websocket_response_t()
  def websocket_request(pid, path, headers) do
    result = GenServer.call(pid, {:websocket_request, path, headers}, 30_000)
    :ok = GenServer.stop(pid, :normal)
    result
  end

  @doc """
  Upgrades the connection to a websocket and returns a stream of
  the received chunks.
  """
  @spec websocket_stream(
          pid(),
          path :: binary(),
          Mint.Types.headers()
        ) :: Provider.stream_response_t()
  def websocket_stream(pid, path, headers) do
    with {:ok, request_ref} <-
           GenServer.call(pid, {:websocket_stream, path, headers}) do
      stream =
        Stream.resource(
          fn -> request_ref end,
          fn
            {:halt, nil} ->
              {:halt, nil}

            request_ref ->
              case GenServer.call(pid, {:next_buffer, request_ref}, :infinity) do
                {:cont, data} -> {data, request_ref}
                {:halt, data} -> {data, {:halt, nil}}
              end
          end,
          fn _ ->
            GenServer.stop(pid, :normal)
            nil
          end
        )

      {:ok, stream}
    end
  end

  @doc """
  Upgrades the connection to a websocket and streams received chunks to
  the process defined by `stream_to`. In the case of a sucessful upgrade,
  this function returns a `{:ok, send_to_websocket}` tuple where
  `send_to_websocket` is a function that can be called to send data
  to the websocket.
  """
  @spec websocket_stream_to(
          pid(),
          path :: binary(),
          Mint.Types.headers(),
          stream_to :: pid
        ) :: Provider.stream_to_response_t()
  def websocket_stream_to(pid, path, headers, stream_to) do
    with {:ok, request_ref} <-
           GenServer.call(pid, {:websocket_stream_to, path, headers, stream_to}) do
      send_to_websocket = fn data ->
        GenServer.cast(pid, {:websocket_send, request_ref, data})
      end

      {:ok, send_to_websocket}
    end
  end

  @impl true
  def init({scheme, host, port, opts}) do
    case Mint.HTTP.connect(scheme, host, port, opts) do
      {:ok, conn} ->
        state = %__MODULE__{conn: conn}
        {:ok, state}

      {:error, error} ->
        {:stop, HTTPError.from_exception(error)}
    end
  end

  @impl true
  def handle_call({:request, method, path, headers, body}, from, state) do
    make_request(state, method, path, headers, body, from: from)
  end

  def handle_call({:stream, method, path, headers, body}, _from, state) do
    make_request(state, method, path, headers, body)
  end

  def handle_call({:stream_to, method, path, headers, body, stream_to}, _from, state) do
    make_request(state, method, path, headers, body, stream_to: stream_to)
  end

  def handle_call({:websocket_request, path, headers}, from, state) do
    upgrade_to_websocket(state, path, headers, from, WebSocketRequest.new(from: from))
  end

  def handle_call({:websocket_stream, path, headers}, from, state) do
    upgrade_to_websocket(state, path, headers, from, WebSocketRequest.new())
  end

  def handle_call({:websocket_stream_to, path, headers, stream_to}, from, state) do
    upgrade_to_websocket(state, path, headers, from, WebSocketRequest.new(stream_to: stream_to))
  end

  def handle_call({:next_buffer, request_ref}, from, state) do
    state = put_in(state.requests[request_ref].waiting, from)
    {:noreply, flush_buffer(state)}
  end

  @impl true
  def handle_cast({:websocket_send, request_ref, data}, state) do
    request = state.requests[request_ref]

    with {:ok, frame} <- WebSocketRequest.map_outgoing_frame(data),
         {:ok, websocket, data} <- Mint.WebSocket.encode(request.websocket, frame),
         {:ok, conn} <- Mint.WebSocket.stream_request_body(state.conn, request_ref, data) do
      state = struct!(state, conn: conn)
      state = put_in(state.requests[request_ref].websocket, websocket)
      {:noreply, state}
    end
  end

  def handle_cast({:terminate_request, request_ref}, state) do
    {_, state} = pop_in(state.requests[request_ref])
    {:noreply, state}
  end

  @impl true
  def handle_info(message, %__MODULE__{conn: conn} = state)
      when Mint.HTTP.is_connection_message(conn, message) do
    case Mint.WebSocket.stream(state.conn, message) do
      {:ok, conn, responses} ->
        state
        |> struct!(conn: conn)
        |> process_responses_or_frames(responses)

      {:error, conn, %Mint.TransportError{reason: :closed}, []} ->
        Logger.debug("The connection was closed.", library: :k8s)

        # We could terminate the process here. But there might still be chunks
        # in the buffer, so we don't.
        {:noreply, struct!(state, conn: conn)}

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

  @impl true
  def terminate(_reason, state) do
    state = flush_buffer(state)

    state
    |> Map.get(:requests)
    |> Enum.filter(fn {_ref, request} -> is_map_key(request, :websocket) end)
    |> Enum.each(fn {request_ref, request} ->
      {:ok, _websocket, data} = Mint.WebSocket.encode(request.websocket, :close)
      Mint.WebSocket.stream_request_body(state.conn, request_ref, data)
    end)

    Mint.HTTP.close(state.conn)
    :ok
  end

  @spec make_request(t(), binary(), binary(), Mint.Types.headers(), binary(), keyword()) ::
          {:noreply, t()} | {:reply, :ok | {:ok, reference()} | {:error, HTTPError.t()}, t()}
  defp make_request(state, method, path, headers, body, extra \\ []) do
    case Mint.HTTP.request(state.conn, method, path, headers, body) do
      {:ok, conn, request_ref} ->
        state =
          put_in(
            state.requests[request_ref],
            HTTPRequest.new(extra)
          )

        cond do
          Keyword.has_key?(extra, :from) -> {:noreply, struct!(state, conn: conn)}
          Keyword.has_key?(extra, :stream_to) -> {:reply, :ok, struct!(state, conn: conn)}
          true -> {:reply, {:ok, request_ref}, struct!(state, conn: conn)}
        end

      {:error, conn, error} ->
        state = struct!(state, conn: conn)

        {:reply, {:error, HTTPError.from_exception(error)}, state}
    end
  end

  @spec upgrade_to_websocket(t(), binary(), Mint.Types.headers(), pid(), WebSocketRequest.t()) ::
          {:noreply, t()} | {:reply, {:error, HTTPError.t(), t()}}
  defp upgrade_to_websocket(state, path, headers, from, websocket_request) do
    case Mint.WebSocket.upgrade(:wss, state.conn, path, headers) do
      {:ok, conn, request_ref} ->
        state =
          put_in(
            state.requests[request_ref],
            UpgradeRequest.new(from: from, websocket_request: websocket_request)
          )

        {:noreply, struct!(state, conn: conn)}

      {:error, conn, error} ->
        {:reply, {:error, HTTPError.from_exception(error)}, struct!(state, conn: conn)}
    end
  end

  @spec process_responses_or_frames(t(), [Mint.Types.response()]) :: {:noreply, t()}
  defp process_responses_or_frames(state, [{:data, request_ref, data}] = responses) do
    request = state.requests[request_ref]

    if is_struct(request, WebSocketRequest) do
      {:ok, websocket, frames} = Mint.WebSocket.decode(request.websocket, data)
      state = put_in(state.requests[request_ref].websocket, websocket)
      process_frames(state, request_ref, frames)
    else
      process_responses(state, responses)
    end
  end

  defp process_responses_or_frames(state, responses) do
    process_responses(state, responses)
  end

  @spec flush_buffer(t()) :: t()
  defp flush_buffer(state) do
    update_in(
      state.requests,
      &Map.new(&1, fn {request_ref, request} ->
        {request_ref, HTTPRequest.flush_buffer(request)}
      end)
    )
  end

  @spec process_frames(t(), reference(), list(Mint.WebSocket.frame())) :: {:noreply, t()}
  defp process_frames(state, request_ref, frames) do
    state =
      frames
      |> Enum.map(&WebSocketRequest.map_frame/1)
      |> Enum.reduce_while(state, fn mapped_frame, state ->
        case get_and_update_in(
               state.requests[request_ref],
               &HTTPRequest.put_response(&1, mapped_frame)
             ) do
          {:stop, state} ->
            # StreamTo requests need to be stopped from inside the GenServer.
            {:halt, {:stop, :normal, state}}

          {_, state} ->
            {:cont, state}
        end
      end)

    case state do
      {:stop, :normal, state} -> {:stop, :normal, flush_buffer(state)}
      state -> {:noreply, flush_buffer(state)}
    end
  end

  @spec process_responses(t(), [Mint.Types.response()]) :: {:noreply, t()}
  defp process_responses(state, responses) do
    state =
      responses
      |> Enum.map(&HTTPRequest.map_response/1)
      |> Enum.reduce(state, fn {mapped_response, request_ref}, state ->
        if mapped_response == :done and match?(%UpgradeRequest{}, state.requests[request_ref]) do
          create_websocket(state, request_ref)
        else
          {_, state} =
            get_and_update_in(
              state.requests[request_ref],
              &HTTPRequest.put_response(&1, mapped_response)
            )

          state
        end
      end)

    {:noreply, flush_buffer(state)}
  end

  @spec create_websocket(t(), reference()) :: t()
  defp create_websocket(state, request_ref) do
    %UpgradeRequest{response: response, from: from, websocket_request: websocket_request} =
      state.requests[request_ref]

    case Mint.WebSocket.new(
           state.conn,
           request_ref,
           response.status,
           response.headers
         ) do
      {:ok, conn, websocket} ->
        if is_nil(websocket_request.from),
          do: GenServer.reply(from, {:ok, request_ref})

        {_, websocket_request} =
          websocket_request
          |> struct!(websocket: websocket)
          |> HTTPRequest.put_response({:open, true})

        put_in(state.requests[request_ref], websocket_request)
        |> struct!(conn: conn)

      {:error, conn, error} ->
        GenServer.reply(from, {:error, HTTPError.from_exception(error)})
        struct!(state, conn: conn)
    end
  end
end
