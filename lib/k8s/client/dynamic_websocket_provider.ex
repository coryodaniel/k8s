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
  @spec request(
          String.t(),
          boolean(),
          keyword(atom()),
          keyword(binary()),
          keyword(tuple()),
          keyword(atom())
        ) ::
          {:ok, pid()} | {:error, binary()}
  def request(_url, _insecure, _ssl_options, _cacerts, _headers, opts) do
    GenServer.call(__MODULE__, {:request, opts})
  end

  @spec stop(pid(), term()) :: :ok
  def stop(_pid, _reason \\ :normal) do
    :ok
  end

  @spec init(atom) :: {:ok, map()}
  def init(:ok) do
    {:ok, %{}}
  end

  @spec handle_info(atom(), state :: term()) :: {:noreply, term()}
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

  @spec handle_call({atom(), term()}, {pid(), any()}, term()) ::
          {:noreply, any()}
          | {:noreply, any(), :hibernate | :infinity | non_neg_integer() | {:continue, any()}}
          | {:reply, any(), any()}
          | {:stop, any(), any()}
          | {:reply, any(), any(),
             :hibernate | :infinity | non_neg_integer() | {:continue, any()}}
          | {:stop, any(), any(), any()}
  def handle_call({:request, opts}, _from, state) do
    stream_to = Keyword.fetch!(opts, :stream_to)
    Process.send_after(self(), :send_command_results, 1_000)
    {:reply, {:ok, self()}, Map.put(state, :from, stream_to)}
  end
end
