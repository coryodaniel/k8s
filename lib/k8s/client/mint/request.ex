defmodule K8s.Client.Mint.Request do
  @moduledoc """
  Maintains the state of a HTTP or Websocket request.
  """

  alias K8s.Client.Mint.ConnectionRegistry

  @typedoc """
  Describes the mode the request is currently in.

  - `::pending` - The request is still streaming its body to the server
  - `:receiving` - The request is currently receiving response parts / frames
  - `:closing` - Websocket requests only: The `:close` frame was received but the process wasn't terminated yet
  - `:terminating` - HTTP requests only: The `:done` part was received but the request isn't cleaned up yet
  """
  @type request_modes :: :pending | :receiving | :closing | :terminating

  @typedoc """
  Defines the state of the request.

  - `:request_ref` - Mint request reference
  - `:caller_ref` - Monitor reference of the calling process.
  - `:stream_to` - the process expecting response parts sent to.
  - `:pool` - the PID of the pool so we can checkin after the last part is sent.
  - `:websocket` - for WebSocket requests: The websocket state (`Mint.WebSocket.t()`).
  - `:mode` - defines what mode the request is currently in.
  - `:buffer` - Holds the buffered response parts or frames that haven't been
    sent to / received by the caller yet
  - `:pending_request_body` - Part of the request body that has not been sent yet.
  """
  @type t :: %__MODULE__{
          request_ref: Mint.Types.request_ref(),
          caller_ref: reference(),
          stream_to: pid() | {pid(), reference()} | nil,
          pool: pid() | nil,
          websocket: Mint.WebSocket.t() | nil,
          mode: request_modes(),
          buffer: list(),
          pending_request_body: binary()
        }

  defstruct [
    :request_ref,
    :caller_ref,
    :stream_to,
    :pool,
    :websocket,
    :pending_request_body,
    mode: :pending,
    buffer: []
  ]

  @spec new(keyword()) :: t()
  def new(fields) do
    mode = if is_nil(fields[:pending_request_body]), do: :receiving, else: :pending
    fields = Keyword.put(fields, :mode, mode)
    struct!(__MODULE__, fields)
  end

  @spec put_response(t(), :done | {atom(), any()}) :: :pop | {t(), t()}
  def put_response(request, response) do
    request
    |> struct!(buffer: [response | request.buffer])
    |> update_mode(response)
    |> send_response()
    |> maybe_terminate_request()
  end

  @spec recv(t(), GenServer.from()) :: :pop | {t(), t()}
  def recv(request, from) do
    request
    |> struct!(stream_to: {:reply, from})
    |> send_response()
    |> maybe_terminate_request()
  end

  @spec update_mode(t(), :done | {atom(), term()}) :: t()
  defp update_mode(%__MODULE__{mode: mode} = request, _) when mode != :receiving, do: request

  defp update_mode(request, {:close, _}) do
    struct!(request, mode: :closing)
  end

  defp update_mode(request, :done) do
    struct!(request, mode: :terminating)
  end

  defp update_mode(request, _), do: request

  @spec maybe_terminate_request(t()) :: {t(), t()} | :pop
  def maybe_terminate_request(%__MODULE__{mode: :closing, buffer: []}), do: :pop

  def maybe_terminate_request(%__MODULE__{mode: :terminating, buffer: []} = request) do
    Process.demonitor(request.caller_ref)
    ConnectionRegistry.checkin(%{pool: request.pool, adapter: self()})
    :pop
  end

  def maybe_terminate_request(request), do: {request, request}

  @spec send_response(t()) :: t()
  defp send_response(%__MODULE__{stream_to: nil} = request) do
    request
  end

  defp send_response(%__MODULE__{stream_to: {:reply, from}, buffer: [_ | _]} = request) do
    GenServer.reply(from, Enum.reverse(request.buffer))
    struct!(request, stream_to: nil, buffer: [])
  end

  defp send_response(%__MODULE__{stream_to: {pid, ref}} = request) do
    request.buffer |> Enum.reverse() |> Enum.each(&send(pid, {ref, &1}))
    struct!(request, buffer: [])
  end

  defp send_response(%__MODULE__{stream_to: pid} = request) do
    request.buffer |> Enum.reverse() |> Enum.each(&send(pid, &1))
    struct!(request, buffer: [])
  end

  @spec map_response({:done, reference()} | {atom(), reference(), any}) ::
          {:done | {atom(), any}, reference()}
  def map_response({:done, ref}), do: {:done, ref}
  def map_response({type, ref, value}), do: {{type, value}, ref}

  @spec map_frame({:binary, binary} | {:close, any, any}) ::
          {:close, {integer(), binary()}}
          | {:error, binary}
          | {:stderr, binary}
          | {:stdout, binary}
  def map_frame({:close, code, reason}), do: {:close, {code, reason}}
  def map_frame({:binary, <<1, msg::binary>>}), do: {:stdout, msg}
  def map_frame({:binary, <<2, msg::binary>>}), do: {:stderr, msg}
  def map_frame({:binary, <<3, msg::binary>>}), do: {:error, msg}
  def map_frame({:binary, msg}), do: {:stdout, msg}

  @spec map_outgoing_frame({:stdin, binary()} | {:close, integer(), binary()} | :close | :exit) ::
          {:ok, :close | {:text, binary} | {:close, integer(), binary()}}
          | K8s.Client.HTTPError.t()
  def map_outgoing_frame({:stdin, data}), do: {:ok, {:text, <<0>> <> data}}
  def map_outgoing_frame(:close), do: {:ok, :close}
  def map_outgoing_frame(:exit), do: {:ok, :close}
  def map_outgoing_frame({:close, code, reason}), do: {:ok, {:close, code, reason}}

  def map_outgoing_frame(data) do
    K8s.Client.HTTPError.new(
      message: "The given message #{inspect(data)} is not supported to be sent to the Pod."
    )
  end

  @spec receive_upgrade_response(Mint.HTTP.t(), reference()) ::
          {:ok, Mint.HTTP.t(), map()} | {:error, Mint.HTTP.t(), Mint.Types.error()}
  def receive_upgrade_response(conn, ref) do
    Enum.reduce_while(Stream.cycle([:ok]), {conn, %{}}, fn _, {conn, response} ->
      case Mint.HTTP.recv(conn, 0, 5000) do
        {:ok, conn, parts} ->
          response =
            parts
            |> Map.new(fn
              {type, ^ref} -> {type, true}
              {type, ^ref, value} -> {type, value}
            end)
            |> Map.merge(response)

          # credo:disable-for-lines:3
          if response[:done],
            do: {:halt, {:ok, conn, response}},
            else: {:cont, {conn, response}}

        {:error, conn, error, _} ->
          {:halt, {:error, conn, error}}
      end
    end)
  end

  @spec stream_request_body(t(), Mint.HTTP.t()) ::
          {:ok, t(), Mint.HTTP.t()} | {:error, Mint.HTTP.t(), Mint.Types.error()}
  def stream_request_body(%__MODULE__{mode: mode} = req, conn) when mode != :pending,
    do: {:ok, req, conn}

  def stream_request_body(request, conn) do
    chunk_size = chunk_size(request, conn)

    %__MODULE__{
      request_ref: request_ref,
      pending_request_body: <<chunk::binary-size(chunk_size), remaining_request_body::binary>>
    } = request

    with {:ok, conn} <- Mint.HTTP.stream_request_body(conn, request_ref, chunk),
         {:remaining_request_body, conn, ""} <-
           {:remaining_request_body, conn, remaining_request_body},
         {:ok, conn} <- Mint.HTTP.stream_request_body(conn, request_ref, :eof) do
      {:ok, struct!(request, mode: :receiving, pending_request_body: nil), conn}
    else
      {:remaining_request_body, conn, remaining_request_body} ->
        {:ok, struct!(request, pending_request_body: remaining_request_body), conn}

      {:error, conn, error} ->
        {:error, conn, error}
    end
  end

  @spec chunk_size(t(), Mint.HTTP.t()) :: non_neg_integer()
  defp chunk_size(request, conn) do
    Enum.min([
      get_window_size(conn, {:request, request.request_ref}),
      get_window_size(conn, :connection),
      byte_size(request.pending_request_body)
    ])
  end

  @spec get_window_size(
          Mint.HTTP.t() | Mint.HTTP2.t(),
          :connection | {:request, Mint.Types.request_ref()}
        ) :: non_neg_integer
  defp get_window_size(conn, connection_or_request) do
    # This is necessary becuase conn types in Mint are opaque and dialyzer
    # would raise if we call Mint.HTTP2.get_window_size() directly with a
    # Mint.HTTP.t() conn.
    #
    # See [elixir-mint/mint#380](https://github.com/elixir-mint/mint/issues/380) for
    # the discussion on it.

    Mint.HTTP2.get_window_size(conn, connection_or_request)
  end
end
