defmodule K8s.Client.Runner.Exec do
  @moduledoc """
  Exec functionality for `K8s.Client`.
  """
  require Logger
  use WebSockex

  alias K8s.Operation
  alias K8s.Conn.RequestOptions
  alias K8s.Discovery


  @doc """
  Execute a command in a Pod's container.

  ## Example

  Running the `date` command inside a nginx pod:

  ```elixir
  conn = K8s.Conn.from_file("~/.kube/config")
  op=K8s.Client.create("v1", "pods/exec", [namespace: "default", name: "nginx", ], [container: "fluentd", command: ["/bin/sh", "-c", "sleep 10 && echo hello"], from: self()])
  K8s.Client.Runner.Exec.run(op, conn, [from: self()])
  ```
  """
  @spec run(Operation.t(), Conn.t(), keyword(atom())) ::
          {:ok, Pid.t()} | {:error, binary()}
  def run(%Operation{name: "pods/exec"} = operation, conn, opts) do

    with {:ok, base_url} <- Discovery.url_for(conn, operation),
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
      WebSockex.start_link(conn, __MODULE__, opts, [async: false])
    else
      {:error, message} -> {:error, message}
      error -> {:error, inspect(error)}
    end
  end
  def run(_,_,_), do: {:error, ""}

  @doc """
   Websocket stdout handler. The frame starts with a 1
  """
  def handle_frame({_type, <<1, "">>}, state) do
    #no need to print out an empty response
    {:ok, state}
  end

  @doc """
    Websocket stdout handler. The frame starts with a 1 and is followed by a message.
  """
  def handle_frame({type, <<1, msg::binary>>}, state) do
    Logger.debug("Exec: Received STDOUT Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}", context: "exec_cmd")
    from = Keyword.get(state, :from)
    send(from, {:ok, msg})
    {:ok, state}
  end

  @doc """
    Websocket sterr handler. The frame starts with a 2 and is followed by a message. In this case an empy message.
  """
  def handle_frame({_type, <<2, "">>}, state) do
    {:ok, state}
  end

  @doc """
    Websocket stderr handler. The frame starts with a 2 and is followed by a message.
  """
  def handle_frame({type, <<2, msg::binary>>}, state) do
    Logger.debug("Exec: Received STDERR Message  - Type: #{inspect(type)} -- Message: #{inspect(msg)}", context: "exec_cmd")
    {:ok, state}
  end

  @doc """
    Websocket uknown command handler. This is a binary frame we are not familiar with.
  """
  def handle_frame({type, msg}, state) do
    Logger.error("Exec Command - Received Unknown Message - Type: #{inspect(type)} -- Message: #{msg}")
    {:ok, state}
  end

  def handle_cast({:send, {type, msg} = frame}, state) do
    Logger.debug("Sending #{type} frame with payload: #{msg}")
    {:reply, frame, state}
  end

  @doc """
    Websocket disconnect handler. This frame is received when the web socket is disconnected.
  """
  def handle_disconnect(data, state) do
    Logger.debug("Local close with reason: #{inspect(data)}", context: "exec_cmd")
    from      = Keyword.get(state, :from)
    send(from, {:exit, inspect(data.reason)})
    {:ok, state}
  end

  defp query_param_builder(params) do
    # do not need this in the query params
    params = Keyword.drop(params, [:from])
    Enum.map(params, fn({k,v}) ->
      case k do
        :command -> command_builder(v, []) |> Enum.join("&") 
        _ -> "#{URI.encode_query(%{k => v})}"
      end
    end)
    |>
    Enum.join("&")
  end

  defp command_builder([], acc), do: Enum.reverse(acc)
  defp command_builder([h | t], acc) do
    params = URI.encode_query(%{"command" => h})
    command_builder(t, ["#{params}" | acc])
  end


end
