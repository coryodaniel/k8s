defmodule K8s.Conn.Auth.ServiceAccount do
  @moduledoc """
  Authentication using a service account token

  This starts a genserver `ServiceAccountWorker` that will periodically refresh the token.
  """

  @behaviour K8s.Conn.Auth

  alias K8s.Conn.Auth.ServiceAccountWorker
  alias K8s.Conn.Error

  defstruct [:pid]

  @type t :: %__MODULE__{pid: GenServer.server()}

  @impl true
  @spec create(map() | any, String.t() | any) :: {:ok, t} | {:error, Error.t() | any()} | :skip
  def create(token_path, _) when is_binary(token_path) do
    # Stat'ing the file here is a choice that allows temporary IO issues to be hidden
    # the genserver will start and then fail to read the file until kubelet fills the token file mount
    with {:ok, _stat} <- File.stat(token_path),
         # Start the worker on the ProviderSupervisor
         {:ok, pid} <-
           DynamicSupervisor.start_child(
             K8s.Conn.Auth.ProviderSupervisor,
             {ServiceAccountWorker, path: token_path}
           ) do
      {:ok, %__MODULE__{pid: pid}}
    else
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
    def generate(%K8s.Conn.Auth.ServiceAccount{pid: pid} = _provider) do
      with {:ok, token} <- ServiceAccountWorker.get_token(pid) do
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
