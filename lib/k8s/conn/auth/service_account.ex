defmodule K8s.Conn.Auth.ServiceAccount do
  @moduledoc """
  Authentication using a service account token

  This starts a genserver `ServiceAccountWorker` that will periodically refresh the token.
  """

  @behaviour K8s.Conn.Auth

  alias K8s.Conn.Auth.ServiceAccountWorker
  alias K8s.Conn.Error

  defstruct [:target]
  @type t :: %__MODULE__{target: GenServer.server()}

  @impl true
  @spec create(map() | any, String.t() | any) :: {:ok, t} | {:error, Error.t() | any()} | :skip
  def create(token_path, _) when is_binary(token_path) do
    # keep the name for later so we can send GenServer.call/2 to it
    # allow the worker to be restarted if it crashes
    name = ServiceAccountWorker.via_tuple(token_path)
    opts = [path: token_path, name: name]

    # Stat'ing the file here is a choice that allows temporary IO issues to be hidden
    # the genserver will start and then fail to read the file until
    # kubelet fills the token file mount
    with {:ok, _stat} <- File.stat(token_path),
         # Start the worker on the ProviderSupervisor
         {:ok, _pid} <-
           DynamicSupervisor.start_child(
             K8s.Conn.Auth.ProviderSupervisor,
             {ServiceAccountWorker, opts}
           ) do
      {:ok, %__MODULE__{target: name}}
    else
      {:error, {:already_started, _}} ->
        {:ok, %__MODULE__{target: name}}

      {:error, _reason} = error ->
        error
    end
  end

  def create(_, _), do: :skip

  defimpl K8s.Conn.RequestOptions, for: K8s.Conn.Auth.ServiceAccount do
    @doc """
    Generates HTTP Authorization options for
    auth-provider authentication by asking the running ExecWorker for a token.
    """
    @spec generate(K8s.Conn.Auth.ServiceAccount.t()) :: K8s.Conn.RequestOptions.generate_t()
    def generate(%K8s.Conn.Auth.ServiceAccount{target: target} = _provider) do
      with {:ok, token} <- ServiceAccountWorker.get_token(target) do
        {
          :ok,
          %K8s.Conn.RequestOptions{
            headers: [{:Authorization, "Bearer #{token}"}],
            ssl_options: []
          }
        }
      end
    end
  end
end
