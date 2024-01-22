defmodule K8s.Conn.Auth.ExecWorker do
  @moduledoc false
  use GenServer

  alias K8s.Conn.Error

  defmodule State do
    @moduledoc """
    The state of the exec worker
    """

    defstruct [
      :command,
      :env,
      args: [],
      token: nil,
      expiration_timestamp: nil,
      refresh_interval: 60_000,
      timer: nil
    ]

    @typedoc """
    Simplified version of [ExecConfig](https://kubernetes.io/docs/reference/config-api/kubeconfig.v1/#ExecConfig)
    """
    @type t :: %__MODULE__{
            command: String.t(),
            env: %{name: String.t()},
            args: list(String.t()),
            token: binary() | nil,
            expiration_timestamp: DateTime.t() | nil,
            refresh_interval: non_neg_integer(),
            timer: reference() | nil
          }
  end

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Given the kube context, parse the options
  and return a keyword list for the exec worker.
  """
  @spec parse_opts(any()) :: Keyword.t()
  def parse_opts(%{"exec" => %{"command" => command} = config}) do
    # Optional:
    args = List.wrap(config["args"])
    env = config["env"] |> List.wrap() |> format_env()

    [
      command: command,
      env: env,
      args: args
    ]
  end

  def parse_opts(_), do: []

  @spec init(Keyword.t()) :: {:ok, State.t()}
  @impl true
  def init(args) do
    state = struct!(State, args)
    # Start a refresh timer
    {:ok, schedule_refresh(state)}
  end

  @spec handle_call(atom(), any(), State.t()) ::
          {:reply, {:ok, binary()}, State.t()}
          | {:reply, {:error, Error.t()}, State.t()}
  @impl true
  def handle_call(:get_token, _from, %State{token: token} = state) when not is_nil(token) do
    if valid_token?(state) do
      {:reply, {:ok, token}, state}
    else
      generate_new_token(state)
    end
  end

  def handle_call(:get_token, _from, state) do
    # Generate a new token if the cached token is expired or not present
    generate_new_token(state)
  end

  @spec get_token(GenServer.server()) ::
          {:ok, binary()} | {:error, Jason.DecodeError.t() | Error.t()}
  def get_token(target) do
    GenServer.call(target, :get_token)
  end

  @impl true
  @spec handle_info(any(), State.t()) :: {:noreply, State.t()}
  def handle_info(:refresh_token, state) do
    case response_from_command(state) do
      {:ok, response} ->
        new_state = state |> update_state_with_response(response) |> schedule_refresh(response)
        {:noreply, new_state}

      {:error, _error} ->
        {:noreply, schedule_refresh(state)}
    end
  end

  @spec generate_new_token(State.t()) ::
          {:reply, {:ok, binary()}, State.t()} | {:reply, {:error, Error.t()}, State.t()}
  defp generate_new_token(%State{} = state) do
    case response_from_command(state) do
      {:ok, %{token: new_token} = response} ->
        new_state = state |> update_state_with_response(response) |> schedule_refresh(response)

        if valid_token?(new_state) do
          {:reply, {:ok, new_token}, new_state}
        else
          {:reply, {:error, %Error{message: "Expired Before Processing"}}, new_state}
        end

      {:error, error} ->
        # Keep the process running
        {:reply, error, %State{state | token: nil}}
    end
  end

  @spec response_from_command(State.t()) ::
          {:ok, %{token: String.t() | nil, expiration_timestamp: DateTime.t() | nil}}
          | {:error, Jason.DecodeError.t() | Error.t()}
  defp response_from_command(%{command: command, args: args, env: env} = _config) do
    # Execute the command by exec'ing the command with the args and env
    with {cmd_response, 0} <- System.cmd(command, args, env: env),
         # parse the binary response from the command
         {:ok, data} <- Jason.decode(cmd_response),
         # If there's a token in the response, return it
         {:ok, %{token: token} = response} when not is_nil(token) <- parse_cmd_response(data) do
      {:ok, response}
    else
      # If the command fails, return an error
      {cmd_response, err_code} when is_binary(cmd_response) and is_integer(err_code) ->
        msg = "#{__MODULE__} failed: #{cmd_response}"
        {:error, %Error{message: msg}}

      # If there's a parse error or the token is nil, return an error
      # this just assumes the errors are useful in some way
      error ->
        {:error, error}
    end
  end

  @spec parse_cmd_response(map) ::
          {:ok, %{token: String.t() | nil, expiration_timestamp: DateTime.t() | nil}}
          | {:error, Jason.DecodeError.t() | Error.t()}
          | {:error, Error.t()}
          | {:error, atom()}
  defp parse_cmd_response(%{
         "kind" => "ExecCredential",
         "status" => %{"token" => token, "expirationTimestamp" => expire}
       }) do
    case DateTime.from_iso8601(expire) do
      {:ok, expiration_timestamp, _} ->
        {:ok, %{token: token, expiration_timestamp: expiration_timestamp}}

      {:error, _} = error ->
        error
    end
  end

  defp parse_cmd_response(%{"kind" => "ExecCredential", "status" => %{"token" => token}}) do
    {:ok, %{token: token, expiration_timestamp: nil}}
  end

  defp parse_cmd_response(_) do
    msg = "#{__MODULE__} failed: Unsupported ExecCredential"
    {:error, %Error{message: msg}}
  end

  @spec format_env(list()) :: map()
  defp format_env(env), do: Map.new(env, &{&1["name"], &1["value"]})

  @spec valid_token?(State.t()) :: boolean()
  defp valid_token?(%State{token: token} = _state) when is_nil(token), do: false
  defp valid_token?(%State{token: token} = _state) when byte_size(token) == 0, do: false
  defp valid_token?(%State{expiration_timestamp: exp} = _state) when is_nil(exp), do: true

  defp valid_token?(%State{expiration_timestamp: exp} = _state),
    do: DateTime.compare(DateTime.utc_now(), exp) == :lt

  @spec update_state_with_response(State.t(), map()) :: State.t()
  defp update_state_with_response(
         %State{} = state,
         %{token: token, expiration_timestamp: expiration_timestamp} = _response
       ) do
    %State{
      state
      | token: token,
        expiration_timestamp: expiration_timestamp
    }
  end

  @spec schedule_refresh(State.t()) :: State.t()
  defp schedule_refresh(%State{} = state) do
    timer =
      Process.send_after(
        self(),
        :refresh_token,
        refresh_delay(state, nil)
      )

    %State{state | timer: timer}
  end

  @spec schedule_refresh(State.t(), map()) :: State.t()
  defp schedule_refresh(
         %State{} = state,
         %{expiration_timestamp: expiration_timestamp} = _response
       ) do
    timer =
      Process.send_after(
        self(),
        :refresh_token,
        refresh_delay(state, expiration_timestamp)
      )

    %State{state | timer: timer}
  end

  @spec refresh_delay(State.t(), DateTime.t() | nil) :: non_neg_integer()
  defp refresh_delay(%State{refresh_interval: max_interval}, nil) do
    min_interval = (max_interval * 0.95) |> round() |> max(1)
    Enum.random(min_interval..max_interval)
  end

  defp refresh_delay(%State{refresh_interval: interval}, time_stamp) do
    # We will wait up the the configured refresh interval
    # or the expiration time, whichever comes first
    max_interval =
      time_stamp
      |> DateTime.diff(DateTime.utc_now(), :millisecond)
      |> min(interval)

    # Rather than always picking the max_interval, we'll remove a little for jitter
    min_interval = (max_interval * 0.95) |> round() |> max(1)

    Enum.random(min_interval..max(max_interval, min_interval + 1))
  end
end
