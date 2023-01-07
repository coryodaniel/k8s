defmodule K8s.Client.Mint.Request.HTTP do
  @moduledoc """
  Represents a HTTP request state.

  ### Fields

  - `:caller_ref` - Monitor reference of the calling process.
  - `:stream_to` - StreamTo requests only: The process expecting response parts sent to.
  - `:pool` - The PID of the pool so we can checkin after the last part is sent.
  """

  alias K8s.Client.Mint.ConnectionRegistry
  alias K8s.Client.Mint.Request.WebSocket, as: WebSocketRequest

  @data_types [:data, :stdout, :stderr, :error]
  @type request_types :: :sync | :stream_to | :stream

  @type t :: %__MODULE__{
          caller_ref: reference(),
          stream_to: pid() | nil,
          pool: pid() | nil
        }

  @type request :: t() | WebSocketRequest.t()

  defstruct [:caller_ref, :stream_to, :pool]

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
end
