defmodule K8s.Client.Mint.ConnectionRegistry do
  @moduledoc """
  A registry for open connections. As HTTP/2 allows simultaneous requests,
  we handle multiple requests with one process. In this case, the registry
  stores the PID of the HTTPAdapter which is connected according to the
  given connection details (URI/opts).

  HTTP/1 only allows one request per connection at a time. In order to
  support simultaneous requests, we need a connection pool. This is where
  the `:poolboy` library comes in.
  """

  use GenServer

  alias K8s.Client.HTTPError
  alias K8s.Client.Mint.HTTPAdapter

  @poolboy_config [
    worker_module: K8s.Client.Mint.HTTPAdapter,
    size: 10,
    max_overflow: 20,
    strategy: :fifo
  ]

  @type uriopts :: {URI.t(), keyword()}
  @type adapter_type_t :: :adapter_pool | :singleton
  @type adapter_pool_t :: %{required(:adapter) => pid(), required(:pool) => pid() | nil}

  @doc """
  Starts the registry.
  """
  @spec start_link(any) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Gets a `HTTPAdapter` process from the registry and runs the given `callback`
  function, passing it the adapter's PID.

  If the process returned by the registry is a pool, it runs the given
  `callback` in a `:poolboy` transaction.
  """
  @spec run(uriopts(), (pid() -> any())) :: any()
  def run({uri, opts}, callback) do
    case GenServer.call(__MODULE__, {:get_or_open, HTTPAdapter.connection_args(uri, opts)}) do
      {:ok, {:singleton, adapter_pid}} ->
        callback.(adapter_pid)

      {:ok, {:adapter_pool, pool_pid}} ->
        :poolboy.transaction(pool_pid, callback)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  ets a `HTTPAdapter` process from the registry.

  If the returned process is an adapter pool, an adapter is checked out from
  the pool and a map with both PIDs is returned.

  If the returned process is an adapter process, a map with its PID and `pool`
  set to `nil` is returned.
  """
  @spec checkout(uriopts()) :: {:ok, adapter_pool_t()} | {:error, HTTPError.t()}
  def checkout({uri, opts}) do
    case GenServer.call(__MODULE__, {:get_or_open, HTTPAdapter.connection_args(uri, opts)}) do
      {:ok, {:singleton, pid}} ->
        {:ok, %{adapter: pid, pool: nil}}

      {:ok, {:adapter_pool, pool_pid}} ->
        try do
          {:ok, %{adapter: :poolboy.checkout(pool_pid), pool: pool_pid}}
        catch
          :exit, {:timeout, _} ->
            {:error,
             HTTPError.new(message: "Failed getting a connection. The connection pool is empty")}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @spec checkin(adapter_pool_t()) :: :ok
  def checkin(%{pool: nil}), do: :ok

  def checkin(%{adapter: worker_pid, pool: pool_pid}) do
    :poolboy.checkin(pool_pid, worker_pid)
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
      {:reply, Map.fetch(adapters, key), {adapters, refs}}
    else
      {scheme, host, port, opts} = key

      # Connect to the server to see if the server supports HTTP/2
      with {:ok, conn} <- Mint.HTTP.connect(scheme, host, port, opts),
           {type, adapter_spec} <- get_adapter_spec(conn, key),
           {:ok, adapter} <-
             DynamicSupervisor.start_child(K8s.Client.Mint.ConnectionSupervisor, adapter_spec) do
        Mint.HTTP.close(conn)
        ref = Process.monitor(adapter)
        refs = Map.put(refs, ref, key)
        adapters = Map.put(adapters, key, {type, adapter})
        {:reply, {:ok, {type, adapter}}, {adapters, refs}}
      else
        {:error, %HTTPError{} = error} ->
          {:error, error}

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

  def handle_info(_, state), do: {:noreply, state}

  @spec get_adapter_spec(Mint.HTTP.t(), HTTPAdapter.connection_args_t()) ::
          {adapter_type_t(), :supervisor.child_spec()}
  defp get_adapter_spec(conn, conn_args) do
    case Mint.HTTP.protocol(conn) do
      :http1 ->
        {:adapter_pool,
         %{id: conn_args, start: {:poolboy, :start_link, [@poolboy_config, conn_args]}}}

      :http2 ->
        {:singleton, {HTTPAdapter, conn_args}}
    end
  end
end
