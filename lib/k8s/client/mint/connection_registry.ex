defmodule K8s.Client.Mint.ConnectionRegistry do
  @moduledoc """
  Opens `Mint.HTTP2` connections and registers them in the GenServer state.
  """

  use GenServer

  alias K8s.Client.HTTPError
  alias K8s.Client.Mint.HTTPAdapter

  @type uriopts :: {URI.t(), keyword()}

  @doc """
  Starts the registry.
  """
  @spec start_link(any) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Ensures there is an adapter associated with the given `key`.
  """
  @spec get(uriopts()) :: {:ok, pid()}
  def get({uri, opts}) do
    GenServer.call(__MODULE__, {:get_or_open, HTTPAdapter.connection_args(uri, opts)})
  end

  @impl true
  def init(:ok) do
    adapters = %{}
    refs = %{}
    {:ok, {adapters, refs}}
  end

  @impl true
  def handle_call({:get_or_open, key}, _from, {adapters, refs}) do
    if Map.has_key?(adapters, key) do
      {:reply, {:ok, Map.get(adapters, key)}, {adapters, refs}}
    else
      case DynamicSupervisor.start_child(
             K8s.Client.Mint.ConnectionSupervisor,
             {HTTPAdapter, key}
           ) do
        {:ok, adapter} ->
          ref = Process.monitor(adapter)
          refs = Map.put(refs, ref, adapter)
          adapters = Map.put(adapters, key, adapter)
          {:reply, {:ok, adapter}, {adapters, refs}}

        {:error, error} ->
          {:reply, {:error, HTTPError.from_exception(error)}, {adapters, refs}}
      end
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {adapters, refs}) do
    {key, refs} = Map.pop(refs, ref)
    adapters = Map.delete(adapters, key)
    {:noreply, {adapters, refs}}
  end
end
