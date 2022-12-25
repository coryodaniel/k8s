defmodule K8s.Client.Mint.Request do
  alias K8s.Client.Mint.UpgradeRequest
  alias K8s.Client.Mint.WebSocketRequest
  @data_types [:data, :stdout, :stderr, :error]

  @type t :: %__MODULE__{}
  @type request :: t() | WebSocketRequest.t() | UpgradeRequest.t()

  defstruct [:from, :stream_to, :waiting, response: %{}]

  @spec new(keyword()) :: t()
  def new(fields), do: struct!(__MODULE__, fields)

  @spec put_response(request(), :done | {atom(), term()}) :: :pop | {request(), request()}
  def put_response(%{response: response, from: from}, :done) when not is_nil(from) do
    response =
      response
      |> Map.update(:data, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.reject(&(&1 |> elem(1) |> is_nil()))

    GenServer.reply(from, {:ok, response})
    :pop
  end

  def put_response(%{response: response, from: from}, {:close, data}) when not is_nil(from) do
    response =
      response
      |> Map.update(:stdout, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.update(:stderr, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.update(:error, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
      |> Map.reject(&(&1 |> elem(1) |> is_nil()))
      |> Map.put(:close, data)

    GenServer.reply(from, {:ok, response})
    :pop
  end

  def put_response(%{stream_to: stream_to} = request, {:close, data})
      when not is_nil(stream_to) do
    send(stream_to, {:close, data})
    {request, request}
  end

  def put_response(%{stream_to: stream_to}, :done) when not is_nil(stream_to) do
    send(stream_to, {:done, true})
    :pop
  end

  def put_response(request, {:close, data}) do
    {request, put_in(request.response[:close], data)}
  end

  def put_response(request, :done) do
    # todo: when to pop?
    {request, put_in(request.response[:done], true)}
  end

  def put_response(%{stream_to: stream_to} = request, {type, new_data})
      when type in @data_types and not is_nil(stream_to) do
    send(stream_to, {type, new_data})
    {request, request}
  end

  def put_response(request, {type, new_data}) when type in @data_types do
    {request, update_in(request, [Access.key(:response), Access.key(type, [])], &[new_data | &1])}
  end

  def put_response(%{stream_to: stream_to} = request, {type, value}) when not is_nil(stream_to) do
    send(stream_to, {type, value})
    {request, request}
  end

  def put_response(request, {type, value}) do
    {request, put_in(request.response[type], value)}
  end

  @spec map_response({:done, reference()} | {atom(), reference(), any}) ::
          {:done | {atom(), any}, reference()}
  def map_response({:done, ref}), do: {:done, ref}
  def map_response({type, ref, value}), do: {{type, value}, ref}

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

    type = if is_map_key(request, :done) or is_map_key(request, :close), do: :halt, else: :cont

    GenServer.reply(request.waiting, {type, buffer})
    struct!(request, response: %{}, waiting: nil)
  end

  def flush_buffer(request), do: request
end
