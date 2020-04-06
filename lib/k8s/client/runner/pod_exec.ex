defmodule K8s.Client.Runner.PodExec do
  @moduledoc """
  Exec functionality for `K8s.Client`.
  """
  require Logger
  use WebSockex

  alias K8s.Operation
  alias K8s.Conn.RequestOptions
  alias K8s.Discovery

  @doc """
  Execute a command in a Pod.

  ## Example

  Running the `nginx -t` command inside a nginx pod and stream back the result to self():

  ```elixir
  conn = K8s.Conn.from_file("~/.kube/config")
  op = K8s.Client.create("v1", "pods/exec", [namespace: "default", name: "nginx", ])
  exec_opts = [command: ["/bin/sh", "-c", "nginx -t"], stdin: true, stderr: true, stdout: true, tty: true, stream_to: self()]
  {:ok, pid} = K8s.Client.Runner.PodExec.run(op, conn, exec_opts)
  ```

  Running the `gem list` command inside the nginx pod's fluentd container and stream bach the result to self():

  ```elixir
  conn = K8s.Conn.from_file("~/.kube/config")
  op = K8s.Client.create("v1", "pods/exec", [namespace: "default", name: "nginx", ])
  exec_opts = [command: ["/bin/sh", "-c", "gem list"], container: "fluentd", stdin: true, stderr: true, stdout: true, tty: true, stream_to: self()]
  {:ok, pid} = K8s.Client.Runner.PodExec.run(op, conn, exec_opts)
  ```

  """
  @spec run(Operation.t(), Conn.t(), keyword(atom())) ::
          {:ok, Pid.t()} | {:error, binary()}
  def run(%Operation{name: "pods/exec"} = operation, conn, opts) when is_list(opts) do
    Process.flag(:trap_exit, true)

    with {:ok, opts} <- process_opts(opts),
         {:ok, base_url} <- Discovery.url_for(conn, operation),
         {:ok, request_options} <- RequestOptions.generate(conn) do
      url = "#{base_url}?#{query_param_builder(opts)}"

      ## headers for websocket connection to k8s API
      headers =
        request_options.headers ++ [{"Accept", "*/*"}, {"Content-Type", "application/json"}]

      cacerts = Keyword.get(request_options.ssl_options, :cacerts)

      conn =
        WebSockex.Conn.new(url,
          insecure: false,
          ssl_options: request_options.ssl_options,
          cacerts: cacerts,
          extra_headers: headers
        )

      WebSockex.start_link(conn, __MODULE__, opts, async: true)
    else
      {:error, message} -> {:error, message}
      error -> {:error, inspect(error)}
    end
  end

  def run(_, _, _), do: {:error, :unsupported_operation}

  @doc """
   Websocket stdout handler. The frame starts with a <<1>> and is a noop because of the empty payload.
  """
  def handle_frame({_type, <<1, "">>}, state) do
    # no need to print out an empty response
    {:ok, state}
  end

  @doc """
    Websocket stdout handler. The frame starts with a <<1>> and is followed by a payload.
  """
  def handle_frame({type, <<1, msg::binary>>}, state) do
    Logger.debug(
      "Pod Command Received STDOUT Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}"
    )

    from = Keyword.get(state, :stream_to)
    send(from, {:ok, msg})
    {:ok, state}
  end

  @doc """
    Websocket sterr handler. The frame starts with a <<2>> and is a noop because of the empy payload.
  """
  def handle_frame({_type, <<2, "">>}, state) do
    # no need to print out an empty response
    {:ok, state}
  end

  @doc """
    Websocket stderr handler. The frame starts with a 2 and is followed by a message.
  """
  def handle_frame({type, <<2, msg::binary>>}, state) do
    Logger.debug(
      "Pod Command Received STDERR Message  - Type: #{inspect(type)} -- Message: #{inspect(msg)}"
    )

    {:ok, state}
  end

  @doc """
    Websocket uknown command handler. This is a binary frame we are not familiar with.
  """
  def handle_frame({type, <<_eot::binary-size(1), msg::binary>>}, state) do
    Logger.error(
      "Exec Command - Received Unknown Message - Type: #{inspect(type)} -- Message: #{msg}"
    )

    from = Keyword.get(state, :stream_to)
    send(from, {:error, msg})
    {:ok, state}
  end

  @doc """
    Websocket disconnect handler. This frame is received when the web socket is disconnected.
  """
  def handle_disconnect(data, state) do
    from = Keyword.get(state, :stream_to)
    send(from, {:exit, data.reason})
    {:ok, state}
  end

  defp process_opts(opts) do
    default = [stream_to: self(), stdin: true, stdout: true, stderr: true, tty: true]
    processed = Keyword.merge(default, opts)
    # check for command
    case Keyword.get(processed, :command) do
      nil -> {:error, ":command is required"}
      _ -> {:ok, processed}
    end
  end

  defp query_param_builder(params) do
    # do not need this in the query params
    Keyword.drop(params, [:stream_to])
    |> Enum.map(fn {k, v} ->
      case k do
        :command -> command_builder(v, []) |> Enum.join("&")
        _ -> "#{URI.encode_query(%{k => v})}"
      end
    end)
    |> Enum.join("&")
  end

  # k8s api can take multiple commands params per request
  defp command_builder([], acc), do: Enum.reverse(acc)

  defp command_builder([h | t], acc) do
    params = URI.encode_query(%{"command" => h})
    command_builder(t, ["#{params}" | acc])
  end
end
