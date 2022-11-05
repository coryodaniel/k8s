defmodule K8s.Client.WebSocketProvider do
  @moduledoc """
  Websocket client for k8s API.
  """
  require Logger
  use WebSockex

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

    WebSockex.start_link(conn, __MODULE__, opts, async: true)
  end

  @doc false
  # Websocket stdout handler. The frame starts with a <<1>> and is a noop because of the empty payload.
  @spec handle_frame({term, binary()}, state :: term) :: {:ok, term}
  def handle_frame({_type, <<1, "">>}, state) do
    # no need to print out an empty response
    {:ok, state}
  end

  # Websocket stdout handler. The frame starts with a <<1>> and is followed by a payload.
  def handle_frame({type, <<1, msg::binary>>}, state) do
    Logger.debug(
      "Pod Command Received STDOUT Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}"
    )

    from = Keyword.get(state, :stream_to)
    send(from, {:ok, msg})
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
  def handle_frame({type, <<_eot::binary-size(1), msg::binary>>}, state) do
    Logger.error(
      "Exec Command - Received Unknown Message - Type: #{inspect(type)} -- Message: #{msg}"
    )

    from = Keyword.get(state, :stream_to)
    send(from, {:error, msg})
    {:ok, state}
  end

  # Websocket disconnect handler. This frame is received when the web socket is disconnected.
  @spec handle_disconnect(any(), state :: term) :: {:ok, term}
  def handle_disconnect(data, state) do
    from = Keyword.get(state, :stream_to)
    send(from, {:exit, data.reason})
    {:ok, state}
  end
end
