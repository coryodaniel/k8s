defmodule K8s.Client.Mint.Request.WebSocket do
  @moduledoc """
  Represents a WebSocket connection state.

  ### Fields

  - `:caller_ref` - Monitor reference of the calling process.
  - `:stream_to` - StreamTo requests only: The process expecting response parts sent to.
  - `:pool` - The PID of the pool so we can checkin after the last part is sent.
  - `:websocket` - The websocket state (`Mint.WebSocket.t()`).
  """

  @type t :: %__MODULE__{
          caller_ref: reference(),
          stream_to: pid() | nil,
          pool: pid() | nil,
          websocket: Mint.WebSocket.t() | nil
        }

  defstruct [:caller, :caller_ref, :stream_to, :pool, :websocket]

  @spec new(keyword()) :: t()
  def new(fields \\ []), do: struct!(__MODULE__, fields)

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
