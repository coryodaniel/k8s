defmodule K8s.Client.DynamicHTTPProvider do
  @moduledoc """
  Allows for registration of `K8s.Client.Provider` handlers per-process.

  Used internally by the test suite for testing/mocking Kubernetes responses.
  """
  use GenServer
  @behaviour K8s.Client.Provider

  @doc "Starts this provider."
  @spec start_link(any) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Locate the handler module for this process or any ancestor"
  @spec locate(pid) :: module() | function() | nil
  def locate(nil), do: nil

  def locate(pid) do
    case GenServer.call(__MODULE__, {:locate, pid}) do
      nil ->
        pid
        |> Process.info(:links)
        |> elem(1)
        |> List.first()
        |> locate()

      handler ->
        handler
    end
  end

  @doc "List all registered handlers"
  @spec list :: map()
  def list, do: GenServer.call(__MODULE__, :list)

  @doc "Register the handler mdoule for this process"
  @spec register(pid(), module() | function()) :: map()
  def register(this_pid, module_or_function) do
    GenServer.call(__MODULE__, {:register, this_pid, module_or_function})
  end

  @doc """
  Dispatch `request/5` to the module registered in the current process or any ancestor.
  """
  @impl true
  def request(method, url, body, headers, opts) do
    locate_and_apply(:request, [method, url, body, headers, opts])
  end

  @doc """
  Dispatch `stream_to/6` to the module registered in the current process or any ancestor.
  """
  @impl true
  def stream(method, url, body, headers, opts) do
    locate_and_apply(:stream, [method, url, body, headers, opts])
  end

  @doc """
  Dispatch `stream_to/6` to the module registered in the current process or any ancestor.
  """
  @impl true
  def stream_to(method, url, body, headers, opts, stream_to) do
    locate_and_apply(:stream_to, [method, url, body, headers, opts, stream_to])
  end

  @doc """
  Dispatch `request/5` to the module registered in the current process or any ancestor.
  """
  @impl true
  def websocket_request(url, headers, opts) do
    locate_and_apply(:websocket_request, [url, headers, opts])
  end

  @doc """
  Dispatch `request/5` to the module registered in the current process or any ancestor.
  """
  @impl true
  def websocket_stream(url, headers, opts) do
    locate_and_apply(:websocket_stream, [url, headers, opts])
  end

  @doc """
  Dispatch `request/5` to the module registered in the current process or any ancestor.
  """
  @impl true
  def websocket_stream_to(url, headers, opts, stream_to) do
    locate_and_apply(:websocket_stream_to, [url, headers, opts, stream_to])
  end

  @spec locate_and_apply(atom(), list()) :: K8s.Client.Provider.response_t()
  defp locate_and_apply(func, args) do
    case locate(self()) do
      nil ->
        raise "No handler module registered for process #{inspect(self())} or parent."

      module when is_atom(module) ->
        apply(module, func, args)

      callback when is_function(callback) ->
        apply(callback, args)
    end
  end

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:locate, this_pid}, _from, pids) do
    {:reply, Map.get(pids, this_pid), pids}
  end

  @impl true
  def handle_call({:register, this_pid, module}, _from, state) do
    new_state = Map.put(state, this_pid, module)
    {:reply, new_state, new_state}
  end
end
