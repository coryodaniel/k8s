defmodule K8s.Client.DynamicHTTPProvider do
  @moduledoc """
  Allows for registration of `K8s.Client.Behaviour` handlers per-process.

  Used internally by the test suite for testing/mocking kubernetes responses.
  """
  use GenServer
  @behaviour K8s.Client.Behaviour

  @impl true
  defdelegate headers(method, request_options), to: K8s.Client.HTTPProvider

  @impl true
  defdelegate handle_response(resp), to: K8s.Client.HTTPProvider

  @doc "Starts this provider."
  @spec start_link(any) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Lookup the handler module for this process"
  @spec lookup(pid) :: module() | function() | nil
  def lookup(this_pid) do
    GenServer.call(__MODULE__, {:lookup, this_pid})
  end

  @doc "List all registered handlers"
  @spec list() :: map()
  def list(), do: GenServer.call(__MODULE__, :list)

  @doc "Register the handler mdoule for this process"
  @spec register(pid(), module() | function()) :: map()
  def register(this_pid, module_or_function) do
    GenServer.call(__MODULE__, {:register, this_pid, module_or_function})
  end

  @doc """
  Dispatch `request/5` to the module registered in the current process.

  If the current process is not register, check its parent. This is useful when requests are made from child processes e.g.: (`Task.async/1`)
  """
  @impl true
  def request(method, url, body, headers, opts) do
    module = lookup(self())

    case module do
      nil ->
        parent =
          self()
          |> Process.info(:links)
          |> elem(1)
          |> List.first()
          |> lookup()

        case parent do
          nil ->
            raise "No handler module registered for process #{self()} or parent."

          parent ->
            response = parent.request(method, url, body, headers, opts)
            handle_response(response)
        end

      module when is_atom(module) ->
        response = module.request(method, url, body, headers, opts)
        handle_response(response)

      func when is_function(func) ->
        response = func.(method, url, body, headers, opts)
        handle_response(response)
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
  def handle_call({:lookup, this_pid}, _from, pids) do
    {:reply, Map.get(pids, this_pid), pids}
  end

  @impl true
  def handle_call({:register, this_pid, module}, _from, state) do
    new_state = Map.put(state, this_pid, module)
    {:reply, new_state, new_state}
  end
end
