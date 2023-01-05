defmodule K8s.Client.Mint.Request.HTTP do
  @moduledoc """
  Represents a HTTP request state.

  ### Fields

  - `:caller` - Synchronous requests only: The calling process.
  - `:stream_to` - StreamTo requests only: The process expecting response parts sent to.
  - `:waiting` - Streamed requests only: The process waiting for the next response part.
  - `:response` - The response containing received parts.
  """

  alias K8s.Client.Mint.ConnectionRegistry
  alias K8s.Client.Mint.Request.Upgrade, as: UpgradeRequest
  alias K8s.Client.Mint.Request.WebSocket, as: WebSocketRequest

  @data_types [:data, :stdout, :stderr, :error, :waiting]
  @type request_types :: :sync | :stream_to | :stream

  @type t :: %__MODULE__{
          caller: pid() | nil,
          caller_ref: reference(),
          stream_to: pid() | nil,
          pool: pid() | nil,
          waiting: pid() | nil,
          response: %{},
          type: request_types()
        }

  @type request :: t() | WebSocketRequest.t() | UpgradeRequest.t()

  defstruct [:caller, :caller_ref, :stream_to, :waiting, :type, :pool, response: %{}]

  @spec new(keyword()) :: t()
  def new(fields), do: struct!(__MODULE__, fields)

  @spec put_response(request(), :done | {atom(), term()}) :: :pop | {request(), request()}
  def put_response(%{type: :sync} = request, :done) do
    response =
      request.response
      |> Map.update(:data, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.reject(&(&1 |> elem(1) |> is_nil()))

    GenServer.reply(request.caller, {:ok, response})
    Process.demonitor(request.caller_ref)
    :pop
  end

  def put_response(%{type: :sync} = request, {:close, data}) do
    response =
      request.response
      |> Map.update(:stdout, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.update(:stderr, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.update(:error, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.reject(&(&1 |> elem(1) |> is_nil()))
      |> Map.put(:close, data)

    GenServer.reply(request.caller, {:ok, response})
    {:stop, request}
  end

  def put_response(%{type: :stream_to} = request, :done) do
    send(request.stream_to, {:done, true})
    Process.demonitor(request.caller_ref)
    ConnectionRegistry.checkin(%{pool: request.pool, adapter: self()})
    :pop
  end

  def put_response(%{type: :stream_to} = request, {:close, data}) do
    send(request.stream_to, {:close, data})
    {:stop, request}
  end

  def put_response(%{type: :stream_to} = request, {type, new_data})
      when type in @data_types do
    send(request.stream_to, {type, new_data})
    {request, request}
  end

  def put_response(%{type: :stream_to} = request, {type, value}) do
    send(request.stream_to, {type, value})
    {request, request}
  end

  def put_response(%{type: :stream} = request, {:close, data}) do
    {request, put_in(request.response[:close], data)}
  end

  def put_response(%{type: :stream} = request, :done) do
    {request, put_in(request.response[:done], true)}
  end

  def put_response(request, {type, new_data}) when type in @data_types do
    {request, update_in(request, [Access.key(:response), Access.key(type, [])], &[new_data | &1])}
  end

  def put_response(request, {type, value}) do
    {request, put_in(request.response[type], value)}
  end

  @spec map_response({:done, reference()} | {atom(), reference(), any}) ::
          {:done | {atom(), any}, reference()}
  def map_response({:done, ref}), do: {:done, ref}
  def map_response({type, ref, value}), do: {{type, value}, ref}

  @doc """
  If there are any parts in the response, they are sent to the process
  registered in the `:waiting` field of that request. The response is cleared
  thereafter.
  """
  @spec flush_buffer(request()) :: request()
  def flush_buffer(%{waiting: waiting, response: response} = request)
      when not is_nil(waiting) and response != %{} do
    buffer =
      response
      |> Map.update(:data, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.update(:stdout, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.update(:stderr, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.update(:error, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Enum.to_list()
      |> Enum.reject(&(&1 |> elem(1) |> is_nil()))

    type = if is_map_key(response, :done) or is_map_key(response, :close), do: :halt, else: :cont
    GenServer.reply(request.waiting, {type, buffer})
    struct!(request, response: %{}, waiting: nil)
  end

  def flush_buffer(request), do: request
end
