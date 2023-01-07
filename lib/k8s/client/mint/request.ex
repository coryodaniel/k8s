defmodule K8s.Client.Mint.Request do
  @moduledoc """
  Maintains the state of a HTTP or Websocket request.

  ### Fields

  - `:caller_ref` - Monitor reference of the calling process.
  - `:stream_to` - StreamTo requests only: The process expecting response parts sent to.
  - `:pool` - The PID of the pool so we can checkin after the last part is sent.
  - `:websocket` - For WebSocket requests: The websocket state (`Mint.WebSocket.t()`).
  """

  alias K8s.Client.Mint.ConnectionRegistry

  @data_types [:data, :stdout, :stderr, :error]
  @type request_types :: :sync | :stream_to | :stream

  @type t :: %__MODULE__{
          caller_ref: reference(),
          stream_to: pid() | nil,
          pool: pid() | nil,
          websocket: Mint.WebSocket.t() | nil
        }

  defstruct [:caller_ref, :stream_to, :pool, :websocket]

  @spec new(keyword()) :: t()
  def new(fields), do: struct!(__MODULE__, fields)

  @spec put_response(t(), :done | {atom(), any()}) :: :pop | {:stop, t()} | {t(), t()}
  def put_response(request, :done) do
    send(request.stream_to, {:done, true})
    Process.demonitor(request.caller_ref)
    ConnectionRegistry.checkin(%{pool: request.pool, adapter: self()})
    :pop
  end

  def put_response(request, {:close, data}) do
    send(request.stream_to, {:close, data})
    {:stop, request}
  end

  def put_response(request, {type, new_data})
      when type in @data_types do
    send(request.stream_to, {type, new_data})
    {request, request}
  end

  def put_response(request, {type, value}) do
    send(request.stream_to, {type, value})
    {request, request}
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
end
