defmodule K8s.Client.DynamicWebSocketProvider do
  @moduledoc """
  Used internally by the test suite for testing/mocking Kubernetes websocket responses.
  """
  use GenServer

  @doc "Starts this provider."
  @spec start_link(any) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Handle a `request/6`.

  """
  def request(_url, _insecure, _ssl_options, _cacerts, _headers, opts) do
    GenServer.call(__MODULE__, {:request, opts})
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_info(:send_command_results, state) do
    from = Map.get(state, :from)
    cmnd_result = {:ok, "Fri Apr 17 23:55:24 UTC 2020\n"}
    websocket_exit = {:exit, {:remote, 1000, ""}}
    trap_exit = {:EXIT, self(), :normal}
    send(from, cmnd_result)
    send(from, websocket_exit)
    send(from, trap_exit)
    {:noreply, state}
  end

  def handle_call({:request, opts}, _from, state) do
    stream_to = Keyword.fetch!(opts, :stream_to)
    Process.send_after(self(), :send_command_results, 1_000)
    {:reply, {:ok, self()}, Map.put(state, :from, stream_to)}
  end
end
