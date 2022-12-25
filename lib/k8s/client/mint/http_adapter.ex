defmodule K8s.Client.Mint.HTTPAdapter do
  use GenServer, restart: :temporary

  alias K8s.Client.{HTTPError, Provider}
  alias K8s.Client.Mint.{Request, UpgradeRequest, WebSocketRequest}

  require Logger
  require Mint.HTTP

  defstruct [:conn, requests: %{}]

  @type t :: %__MODULE__{}

  @spec start_link({URI.t(), keyword()}) :: GenServer.on_start()
  def start_link({uri, opts}) do
    GenServer.start_link(__MODULE__, {uri, opts})
  end

  @spec request(
          pid(),
          method :: binary(),
          path :: binary(),
          Mint.Types.headers(),
          body :: iodata() | nil | :stream
        ) :: Provider.response_t()
  def request(pid, method, path, headers, body) do
    GenServer.call(pid, {:request, method, path, headers, body})
  end

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
            :halt ->
              nil

            request_ref ->
              case GenServer.call(pid, {:next_buffer, request_ref}) do
                {:cont, data} -> {data, request_ref}
                {:halt, data} -> {data, :halt}
              end
          end,
          fn _ -> nil end
        )

      {:ok, stream}
    end
  end

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

  @spec websocket_request(
          pid(),
          path :: binary(),
          Mint.Types.headers()
        ) :: Provider.websocket_response_t()
  def websocket_request(pid, path, headers) do
    GenServer.call(pid, {:websocket_request, path, headers})
  end

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
            :halt ->
              nil

            request_ref ->
              case GenServer.call(pid, {:next_buffer, request_ref}) do
                {:cont, data} -> {data, request_ref}
                {:halt, data} -> {data, :halt}
              end
          end,
          fn _ -> nil end
        )

      {:ok, stream}
    end
  end

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
  def init({uri, opts}) do
    case Mint.HTTP.connect(
           String.to_atom(uri.scheme),
           uri.host,
           uri.port,
           opts
         ) do
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

  @impl true
  def handle_info(message, %__MODULE__{conn: conn} = state)
      when Mint.HTTP.is_connection_message(conn, message) do
    case Mint.WebSocket.stream(state.conn, message) do
      {:ok, conn, responses} ->
        state
        |> struct!(conn: conn)
        |> process_responses_or_frames(responses)

      {:error, conn, %Mint.TransportError{reason: :closed}, []} ->
        Logger.debug(
          "The connection was closed. I'm stopping this process now.",
          library: :k8s
        )

        {:stop, :normal, struct!(state, conn: conn)}

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
          {:noreply, t()} | {:reply, {:ok, reference()} | {:error, HTTPError.t()}, t()}
  defp make_request(state, method, path, headers, body, extra \\ []) do
    case Mint.HTTP.request(state.conn, method, path, headers, body) do
      {:ok, conn, request_ref} ->
        state =
          put_in(
            state.requests[request_ref],
            Request.new(extra)
          )

        if Keyword.has_key?(extra, :from),
          do: {:noreply, struct!(state, conn: conn)},
          else: {:reply, {:ok, request_ref}, struct!(state, conn: conn)}

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
        {request_ref, Request.flush_buffer(request)}
      end)
    )
  end

  @spec process_frames(t(), reference(), list(Mint.WebSocket.frame())) :: {:noreply, t()}
  defp process_frames(state, request_ref, frames) do
    state =
      for frame <- frames, reduce: state do
        state ->
          mapped_frame = WebSocketRequest.map_frame(frame)
          put_response(state, mapped_frame, request_ref)
      end

    {:noreply, flush_buffer(state)}
  end

  @spec process_responses(t(), [Mint.Types.response()]) :: {:noreply, t()}
  defp process_responses(state, responses) do
    state =
      for response <- responses, reduce: state do
        state ->
          {mapped_response, request_ref} = Request.map_response(response)
          put_response(state, mapped_response, request_ref)
      end

    {:noreply, flush_buffer(state)}
  end

  @spec put_response(t(), {:done} | {atom(), term}, reference) :: t()
  defp put_response(state, :done, request_ref) do
    case state.requests[request_ref] do
      %UpgradeRequest{} ->
        create_websocket(state, request_ref)

      _ ->
        {_, state} =
          get_and_update_in(state.requests[request_ref], &Request.put_response(&1, :done))

        state
    end
  end

  defp put_response(state, response, request_ref) do
    {_, state} =
      get_and_update_in(state.requests[request_ref], &Request.put_response(&1, response))

    state
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
          |> Request.put_response({:open, true})

        put_in(state.requests[request_ref], websocket_request)
        |> struct!(conn: conn)

      {:error, conn, error} ->
        GenServer.reply(from, {:error, HTTPError.from_exception(error)})
        struct!(state, conn: conn)
    end
  end
end
