defmodule K8s.Conn.Auth.CertificateWorker do
  @moduledoc """
  This gen server is responsible for managing
  the certificate and key from filesystem paths.

  It read the key and certificate from the file system

  It caches them in memory and refreshes them periodically
  """
  use GenServer

  alias K8s.Conn.PKI

  defmodule State do
    @moduledoc """
    The state of the exec worker
    """

    defstruct [
      :cert_path,
      :key_path,
      refresh_interval: 60_000,
      timer: nil,
      cert: nil,
      key: nil
    ]

    @typedoc """
    The state of the certificate worker

    cert_path is the path to the certificate file
    key_path is the path to the key file

    They are both required and must be readable

    refresh_interval is the time in milliseconds to wait before refreshing the certificate and key

    cert is the current certificate. It is nil if the certificate has not been read
    key is the current key. It is nil if the key has not been read

    Timer is the reference to the timer that will refresh the certificate and key if it is not nil.
    """
    @type t :: %__MODULE__{
            cert_path: String.t(),
            key_path: String.t(),
            cert: binary() | nil,
            key: binary() | nil,
            refresh_interval: non_neg_integer(),
            timer: reference() | nil
          }
  end

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  @spec init(any()) :: {:ok, State.t()}
  def init(opts) do
    state = struct!(State, opts)
    # Start a refresh timer
    {:ok, start_refresh_timer(state)}
  end

  @impl true
  def handle_call(:get_cert_and_key, _from, %State{cert: cert, key: key} = state)
      when not is_nil(key) and not is_nil(cert) do
    {:reply, {:ok, %{cert: cert, key: key}}, state}
  end

  def handle_call(
        :get_cert_and_key,
        _from,
        %State{cert_path: cert_path, key_path: key_path} = state
      ) do
    with {:ok, cert} <- PKI.cert_from_pem(cert_path),
         {:ok, key} <- PKI.private_key_from_pem(key_path) do
      new_state = state |> reset_timer() |> start_refresh_timer()
      {:reply, {:ok, %{cert: cert, key: key}}, %State{new_state | cert: cert, key: key}}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  @spec handle_info(any(), State.t()) :: {:noreply, State.t()}
  def handle_info(:refresh, %State{cert_path: cert_path, key_path: key_path} = state) do
    with {:ok, cert} <- PKI.cert_from_pem(cert_path),
         {:ok, key} <- PKI.private_key_from_pem(key_path) do
      new_state = state |> reset_timer() |> start_refresh_timer()
      {:noreplt, %State{new_state | cert: cert, key: key}}
    else
      _ ->
        {:noreply, state}
    end
  end

  @spec get_cert_and_key(atom() | pid() | {atom(), any()} | {:via, atom(), any()}) ::
          {:ok, %{key: binary(), cert: binary()}} | {:error, any()}
  def get_cert_and_key(target) do
    GenServer.call(target, :get_cert_and_key)
  end

  @spec reset_timer(State.t()) :: State.t()
  defp reset_timer(%State{timer: timer} = state) do
    if timer != nil do
      Process.cancel_timer(timer)
    end

    %State{state | timer: nil}
  end

  @spec start_refresh_timer(State.t()) :: State.t()
  defp start_refresh_timer(state) do
    %State{state | timer: Process.send_after(self(), :refresh, state.refresh_interval)}
  end
end
