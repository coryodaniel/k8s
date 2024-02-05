defmodule K8s.Conn.Auth.ServiceAccountWorker do
  @moduledoc """
  A GenServer that reads a service account token from a file and refreshes it

  This looks like total overkill. However service account
  tokens are often network mounts that are not immediately
  available. They refresh all the time and prone to errors. This does its
  best to keep the token fresh and available.

  After the token is read, it is stored in the state of the
  GenServer meaning one read per token lifetime needs to succeed..

  After the token is read, a timer is set to refresh the token. That refresh is
  jittered and opoprtunistic. We don't return known expired tokens, but we
  don't wait until the token is expired to refresh it. If there's an error we will
  schedule a refresh for hopefuly before the token stops working.
  """
  use GenServer

  defmodule State do
    @moduledoc """
    The state of the service account worker
    """

    defstruct [
      :path,
      refresh_interval: 60_000,
      error_refresh_interval: 1000,
      token: nil,
      timer: nil
    ]

    @typedoc """
    The state of the service account worker

    Path must exits and be readable. The token is read from the file and stored in the state.
    Refresh interval is the time in milliseconds to wait before refreshing the token.
    Error refresh interval is the time in milliseconds to wait before refreshing the token after an error.

    Token is the current token. It is nil if the token has not been read
    Timer is the reference to the timer that will refresh the token if it is not nil.
    """
    @type t :: %__MODULE__{
            path: String.t(),
            refresh_interval: non_neg_integer(),
            error_refresh_interval: non_neg_integer(),
            token: binary() | nil,
            timer: reference() | nil
          }
  end

  @state_opts ~w(path refresh_interval error_refresh_interval)a

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    {worker_opts, server_opts} = Keyword.split(opts, @state_opts)

    GenServer.start_link(__MODULE__, worker_opts, server_opts)
  end

  @spec init(Keyword.t()) :: {:ok, State.t()}
  @impl true
  def init(args) do
    # Parse the args
    starting_state = struct!(State, args)

    # Start a refresh timer for just about now.
    {:ok,
     %State{starting_state | timer: start_refresh_timer(starting_state.error_refresh_interval)}}
  end

  @spec via_tuple(any()) ::
          {:via, Registry, {K8s.Conn.Auth.Registry, {K8s.Conn.Auth.ServiceAccountWorker, any()}}}
  def via_tuple(path) do
    {:via, Registry, {K8s.Conn.Auth.Registry, {__MODULE__, path}}}
  end

  @spec get_token(GenServer.server()) :: {:ok, binary()} | {:error, any()}
  def get_token(target) do
    GenServer.call(target, :get_token)
  end

  @spec handle_call(atom(), any(), State.t()) ::
          {:reply, {:ok, binary()}, State.t()} | {:reply, {:error, any()}, State.t()}
  @impl true
  def handle_call(:get_token, _from, %State{token: token} = state) when not is_nil(token) do
    {:reply, {:ok, token}, state}
  end

  def handle_call(:get_token, _from, %State{} = state) do
    # read the token from the file
    # save it in the state
    case read_token(state) do
      {:ok, token_data} ->
        # We had to read the token from the file, so we
        # should schedule a refresh.
        without_timer = reset_timer(state)

        {:reply, {:ok, token_data},
         %State{
           without_timer
           | token: token_data,
             timer: start_refresh_timer(state.refresh_interval)
         }}

      {:error, _} = error ->
        # We're here and no parsable token.
        {:reply, error, %State{state | token: nil}}
    end
  end

  @impl true
  def handle_info(:refresh_token, %State{} = state) do
    case read_token(state) do
      {:ok, token_data} ->
        # The refresh did the work and got a new token so reset the timer.
        without_timer = reset_timer(state)

        {:noreply,
         %State{
           without_timer
           | token: token_data,
             timer: start_refresh_timer(state.refresh_interval)
         }}

      {:error, _} ->
        without_timer = reset_timer(state)

        {:noreply,
         %State{without_timer | timer: start_refresh_timer(without_timer.error_refresh_interval)}}
    end
  end

  @spec read_token(State.t()) :: {:ok, binary()} | {:error, :file_read_error}
  defp read_token(%State{path: path}) do
    case File.read(path) do
      {:ok, token_data} ->
        {:ok, token_data}

      {:error, _} ->
        {:error, :file_read_error}
    end
  end

  @spec start_refresh_timer(non_neg_integer()) :: reference()
  defp start_refresh_timer(refresh_interval) do
    min_interval = (refresh_interval * 0.95) |> round() |> max(1)

    jitter_time = Enum.random(min_interval..refresh_interval)

    Process.send_after(self(), :refresh_token, jitter_time)
  end

  @spec reset_timer(State.t()) :: State.t()
  defp reset_timer(state) do
    if state.timer != nil do
      Process.cancel_timer(state.timer)
    end

    %State{state | timer: nil}
  end
end
