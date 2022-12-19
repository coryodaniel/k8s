defmodule K8s.Client.Mint.WebSocket do
  @moduledoc """
  Websocket implementation of Mint based `K8s.Client.Provider`
  """

  alias K8s.Client.HTTPError
  alias K8s.Client.Provider

  require Mint.HTTP

  @type t :: %__MODULE__{
          conn: Mint.HTTP.t(),
          ref: Mint.Types.request_ref() | nil,
          websocket: Mint.WebSocket.t() | nil
        }

  defstruct [:conn, :ref, :websocket]

  @spec request(
          uri :: URI.t(),
          headers :: list(),
          http_opts :: keyword()
        ) :: Provider.websocket_response_t()
  def request(uri, headers, http_opts) do
    with {:ok, stream} <- stream(uri, headers, http_opts) do
      response =
        stream
        |> Enum.reduce(%{stdout: [], stderr: [], error: []}, fn
          {:stdout, responses}, acc -> Map.update!(acc, :stdout, &[responses | &1])
          {:stderr, responses}, acc -> Map.update!(acc, :stderr, &[responses | &1])
          {:error, responses}, acc -> Map.update!(acc, :error, &[responses | &1])
          _other, acc -> acc
        end)
        |> Map.update!(:stdout, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
        |> Map.update!(:stderr, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
        |> Map.update!(:error, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))

      {:ok, response}
    end
  end

  @spec stream(
          uri :: URI.t(),
          headers :: list(),
          http_opts :: keyword()
        ) :: Provider.stream_response_t()
  def stream(uri, headers, http_opts) do
    transport_opts = Keyword.fetch!(http_opts, :ssl)

    path =
      IO.iodata_to_binary([
        uri.path,
        if(uri.query, do: ["?" | uri.query], else: [])
      ])

    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)

    with {:ok, conn} <-
           K8s.Client.Mint.HTTP.connect(uri, transport_opts: transport_opts, protocols: [:http1]),
         {:ok, state} <- upgrade_to_websocket(conn, path, headers) do
      stream =
        [:open]
        |> Stream.concat(create_stream(fn -> state end))
        |> Stream.map(&map_responses/1)

      {:ok, stream}
    else
      {:error, conn, error}
      when is_exception(error, Mint.HTTPError) or is_exception(error, Mint.TransportError) or
             is_exception(error, Mint.WebSocketError) or
             is_exception(error, Mint.WebSocket.UpgradeFailureError) ->
        Mint.HTTP.close(conn)

        {:error, HTTPError.new(message: Exception.message(error), adapter_specific_error: error)}

      error ->
        error
    end
  end

  @spec upgrade_to_websocket(Mint.HTTP.t(), binary(), list()) ::
          {:ok, t()} | {:error, Mint.HTTP.t(), Mint.WebSocket.error()}
  defp upgrade_to_websocket(conn, path, headers) do
    with {:ok, conn, ref} <- Mint.WebSocket.upgrade(:wss, conn, path, headers),
         [{:status, ^ref, status}, {:headers, ^ref, resp_headers} | _] <-
           create_stream(fn -> struct!(__MODULE__, conn: conn, ref: ref) end) |> Enum.to_list(),
         {:ok, conn, websocket} <- Mint.WebSocket.new(conn, ref, status, resp_headers) do
      Process.flag(:trap_exit, true)
      {:ok, struct!(__MODULE__, conn: conn, ref: ref, websocket: websocket)}
    end
  end

  @spec create_stream(fun()) ::
          Enumerable.t(K8s.Client.Provider.stream_chunk_t())
  defp create_stream(start_fn) do
    Stream.resource(
      start_fn,
      &next_fun/1,
      fn
        %{websocket: nil} ->
          nil

        %{conn: conn} ->
          # TODO
          Mint.HTTP.close(conn)
      end
    )
  end

  @spec next_fun({:error, t(), HTTPError.t()}) :: {[HTTPError.t()], {:halt, t()}}
  defp next_fun({:error, state, error}), do: {[error], {:halt, state}}

  @spec next_fun({:halt, t()}) :: {:halt, t()}
  defp next_fun({:halt, state}), do: {:halt, state}

  @spec next_fun(t()) :: {Enumerable.t(), t()}
  defp next_fun(%__MODULE__{websocket: nil, ref: ref} = state) do
    receive do
      message when Mint.HTTP.is_connection_message(state.conn, message) ->
        with {:ok, conn, responses} <- Mint.WebSocket.stream(state.conn, message) do
          next_state = struct!(state, conn: conn)

          next_state =
            if {:done, ref} == List.last(responses),
              do: {:halt, next_state},
              else: next_state

          {responses, next_state}
        end

      _other ->
        {[], state}
    end
  end

  defp next_fun(%__MODULE__{conn: conn, websocket: websocket, ref: ref} = state) do
    receive do
      message when Mint.HTTP.is_connection_message(conn, message) ->
        with {:ok, conn, [{:data, ^ref, data}]} <- Mint.WebSocket.stream(state.conn, message),
             {:ok, websocket, frames} <- Mint.WebSocket.decode(websocket, data) do
          next_state = struct!(state, conn: conn, websocket: websocket)

          next_state =
            if {:close, 1_000, ""} == List.last(frames), do: {:halt, next_state}, else: next_state

          {frames, next_state}
        end

      {:stdin, cmd} ->
        with {:ok, conn, websocket} <-
               send_to_websocket(conn, websocket, ref, {:text, <<0>> <> cmd}) do
          {[], struct!(state, conn: conn, websocket: websocket)}
        end

      :exit ->
        with {:ok, conn, websocket} <- send_to_websocket(conn, websocket, ref, :close) do
          {[], struct!(state, conn: conn, websocket: websocket)}
        end

      {:exit, code, reason} ->
        with {:ok, conn, websocket} <-
               send_to_websocket(conn, websocket, ref, {:close, code, reason}) do
          {[], struct!(state, conn: conn, websocket: websocket)}
        end

      {:EXIT, _, _} ->
        with {:ok, conn, websocket} <- send_to_websocket(conn, websocket, ref, :close) do
          {[], struct!(state, conn: conn, websocket: websocket)}
        end

      _other ->
        {[], state}
    end
  end

  @spec send_to_websocket(
          Mint.HTTP.t(),
          Mint.WebSocket.t(),
          Mint.Types.request_ref(),
          Mint.WebSocket.frame() | Mint.WebSocket.shorthand_frame()
        ) :: {:ok, Mint.HTTP.t(), Mint.WebSocket.t()}
  defp send_to_websocket(conn, websocket, ref, frame) do
    with {:ok, websocket, data} <- Mint.WebSocket.encode(websocket, frame),
         {:ok, conn} <- Mint.WebSocket.stream_request_body(conn, ref, data) do
      {:ok, conn, websocket}
    end
  end

  @spec map_responses(
          {atom(), Mint.Types.request_ref()}
          | {atom(), Mint.Types.request_ref(), term()}
        ) :: atom() | {atom(), term()}
  defp map_responses({:close, 1000, ""}), do: :close
  defp map_responses({:binary, <<1, msg::binary>>}), do: {:stdout, msg}
  defp map_responses({:binary, <<2, msg::binary>>}), do: {:stderr, msg}
  defp map_responses({:binary, <<3, msg::binary>>}), do: {:error, msg}
  defp map_responses({:binary, <<type::binary-size(1), msg::binary>>}), do: {:binary, type, msg}
  defp map_responses(type) when is_atom(type), do: type
  defp map_responses({type, _ref}), do: type

  defp map_responses({type, _ref, data}), do: {type, data}
end
