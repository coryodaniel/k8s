defmodule K8s.Client.WebSocketProvider do
  @moduledoc """
  Websocket client for k8s API.
  """

  require Logger
  use WebSockex

  defstruct [:monitor_ref, :stream_to]
  @dialyzer {:nowarn_function, handle_info: 2}

  @doc """
  Make a connection to the K8s API and upgrade to a websocket. This is useful for streaming resources like /exec, /logs, /attach  

  ## Example

  ```elixir
  url = "https://localhost:6443/api/v1/namespaces/test/pods/nginx-pod/exec?command=%2Fbin%2Fsh&command=-c&command=date&stdin=true&stderr=true&stdout=true&tty=true"
  insecure = false
  ssl_options = [cert: <<1,2>>, key: {:RSAPrivateKey, <<48, 130>>}, verify: :verify_none]
  cacerts = [<<1,2,3>>,<1,2,3>>]
  headers = [{"Accept", "*/*"}, {"Content-Type", "application/json"}]
  opts = [command    : ["/bin/sh", "-c", "date"], stdin: true, stderr: true, stdout: true, tty: true, stream_to: #PID<0.271.0>]
  {:ok, pid} = K8s.Client.WebSocketProvider.request(url, ssl_options, cacerts, headers, opts)
  ```

  """
  @spec request(
          String.t(),
          boolean(),
          keyword(atom()),
          keyword(binary()),
          keyword(tuple()),
          keyword(atom())
        ) ::
          {:ok, pid()} | {:error, binary()}
  def request(url, insecure, ssl_options, cacerts, headers, opts) do
    conn =
      WebSockex.Conn.new(url,
        insecure: insecure,
        ssl_options: ssl_options,
        cacerts: cacerts,
        extra_headers: headers
      )

    state = %__MODULE__{stream_to: opts[:stream_to]}
    WebSockex.start_link(conn, __MODULE__, state, async: true)
  end

  @spec handle_connect(conn :: WebSockex.Conn.t(), state :: term) :: {:ok, term}
  def handle_connect(_conn, %{monitor_ref: nil, stream_to: stream_to} = state) do
    ref = Process.monitor(stream_to)

    {:ok, %{state | monitor_ref: ref}}
  end

  # In case of a disconnects handle_connect/2 will be called again
  def handle_connect(_conn, state) do
    {:ok, state}
  end

  @doc false
  # Websocket stdout handler. The frame starts with a <<1>> and is a noop because of the empty payload.
  @spec handle_frame({term, binary()}, state :: term) :: {:ok, term}
  def handle_frame({_type, <<1, "">>}, state) do
    # no need to print out an empty response
    {:ok, state}
  end

  # Websocket stdout handler. The frame starts with a <<1>> and is followed by a payload.
  def handle_frame({type, <<1, msg::binary>>}, %{stream_to: stream_to} = state) do
    Logger.debug(
      "Pod Command Received STDOUT Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}"
    )

    send(stream_to, {:ok, msg})
    {:ok, state}
  end

  # Websocket sterr handler. The frame starts with a <<2>> and is a noop because of the empy payload.
  def handle_frame({_type, <<2, "">>}, state) do
    # no need to print out an empty response
    {:ok, state}
  end

  # Websocket stderr handler. The frame starts with a 2 and is followed by a message.
  def handle_frame({type, <<2, msg::binary>>}, state) do
    Logger.debug(
      "Pod Command Received STDERR Message  - Type: #{inspect(type)} -- Message: #{inspect(msg)}"
    )

    {:ok, state}
  end

  # Websocket uknown command handler. This is a binary frame we are not familiar with.
  def handle_frame({type, <<_eot::binary-size(1), msg::binary>>}, %{stream_to: stream_to} = state) do
    Logger.error(
      "Exec Command - Received Unknown Message - Type: #{inspect(type)} -- Message: #{msg}"
    )

    send(stream_to, {:error, msg})
    {:ok, state}
  end

  # Websocket disconnect handler. This frame is received when the web socket is disconnected.
  @spec handle_disconnect(any(), state :: term) :: {:ok, term}
  def handle_disconnect(data, %{stream_to: stream_to} = state) do
    send(stream_to, {:exit, data.reason})
    {:ok, state}
  end

  # Catch when the monitored process dies
  # Invoked to handle all other non-WebSocket messages.
  @spec handle_info(msg :: term, state :: term) ::
          {:close, term}
          | {:ok, term}
          | {:close, {integer(), binary()}, term}
          | {:reply,
             :ping
             | :pong
             | {:binary, binary()}
             | {:ping, nil | binary()}
             | {:pong, nil | binary()}
             | {:text, binary()}, term}
  def handle_info({:DOWN, ref, :process, _, _}, %{monitor_ref: ref}) do
    {:"$EXIT", {:stop, :normal}}
  end
end
