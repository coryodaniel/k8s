defmodule K8s.Client.Runner.Stream.ConnectRequest do
  @moduledoc "`:connect` `K8s.Operation` encapsulated with pagination and `K8s.Conn`"

  @type t :: %__MODULE__{
          operation: K8s.Operation.t(),
          conn: K8s.Conn.t(),
          continue: :halt | :cont,
          http_opts: keyword(),
          recv_ref: reference(),
          monitor_pid: pid(),
          monitor_ref: reference()
        }
  alias K8s.Client.Runner.Base

  defstruct [
    :operation,
    :conn,
    :recv_ref,
    :monitor_pid,
    :monitor_ref,
    continue: :cont,
    http_opts: []
  ]

  @doc """
  Creates a `ConnectRequest` and spawns a process that will own and consume
  the ws connection.
  """
  def init(conn, op, http_opts \\ []) do
    parent = self()
    recv_ref = make_ref()

    {monitor_pid, monitor_ref} =
      spawn_monitor(fn -> init_stream(parent, recv_ref, conn, op, http_opts) end)

    %__MODULE__{
      conn: conn,
      operation: op,
      http_opts: http_opts,
      monitor_pid: monitor_pid,
      monitor_ref: monitor_ref,
      recv_ref: recv_ref
    }
  end

  @doc """
  Receive the next message from the connection:

  * If the ws conneciton exits with normal emit `{:exit, :normal}`
  * Any reason such as errors are passed as is `{:error, term()}`
  * Messages from the ws connection are sent to the parent as a `{:message, ref, msg}`
  """
  def next(%__MODULE__{continue: :halt} = t) do
    {:halt, t}
  end

  def next(%__MODULE__{continue: :cont, monitor_ref: ref, recv_ref: recv_ref} = t) do
    receive do
      {:DOWN, ^ref, _, _, reason} ->
        # emit exit reason, set next state to be halted
        msg =
          if is_atom(reason) do
            {:exit, reason}
          else
            reason
          end

        {[msg], %{t | continue: :halt}}

      {:message, ^recv_ref, msg} ->
        lines = String.split(msg, "\r\n")
        {lines, t}
    end
  end

  @doc """
  Close the monitor and ws connection.
  """
  def close_stream(%__MODULE__{monitor_pid: pid, monitor_ref: m_ref, recv_ref: ref}) do
    send(pid, {:stop, ref})

    Process.demonitor(m_ref, [:flush])
  end

  defp init_stream(parent, recv_ref, conn, op, opts) do
    run = opts[:run] || (&Base.run/3)
    opts = Keyword.put(opts, :stream_to, self())
    parent_ref = Process.monitor(parent)

    case run.(conn, op, opts) do
      {:ok, pid} ->
        stream_ref = Process.monitor(pid)
        recv({parent, parent_ref}, recv_ref, {pid, stream_ref})

      {:error, reason} ->
        exit(reason)
    end
  end

  defp recv({parent, parent_ref} = p, recv_ref, {stream_pid, stream_ref} = s) do
    receive do
      {:ok, msg} ->
        send(parent, {:message, recv_ref, msg})
        recv(p, recv_ref, s)

      {:stop, ^stream_ref} ->
        K8s.websocket_provider().stop(stream_pid)

      {:DOWN, ^parent_ref, _, _, reason} ->
        K8s.websocket_provider().stop(stream_pid)
        exit(reason)

      {:DOWN, ^stream_ref, _, _, reason} ->
        exit(reason)

      _other ->
        # {:exit, {:remote, _, _}}
        # Send these messages to parent?
        recv(p, recv_ref, s)
    end
  end
end
