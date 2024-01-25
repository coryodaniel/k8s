defmodule K8s.Conn.Auth.Exec do
  @moduledoc """
  Cluster authentication for kube configs using an `exec` section.

  Useful for Kubernetes clusters running on AWS which use IAM authentication (eg. the `aws-iam-authenticator` binary).
  An applicable kube config may look something like this:

  ```
  # ...
  users:
  - name: staging-user
    user:
      exec:
        # API version to use when decoding the ExecCredentials resource. Required.
        apiVersion: client.authentication.k8s.io/v1alpha1

        # Command to execute. Required.
        command: aws-iam-authenticator

        # Arguments to pass when executing the plugin. Optional.
        args:
        - token
        - -i
        - staging

        # Environment variables to set when executing the plugin. Optional.
        env:
        - name: "FOO"
          value: "bar"
  ```
  """

  @behaviour K8s.Conn.Auth

  alias __MODULE__
  alias K8s.Conn.Auth.ExecWorker
  alias K8s.Conn.Error

  defstruct [:target]

  @type t :: %__MODULE__{target: GenServer.server()}

  @impl true
  @spec create(map() | any, String.t() | any) :: {:ok, t} | {:error, Error.t()} | :skip
  def create(%{"exec" => %{}} = ctx, _) do
    # We don't want to be in the habit of parsing command names for unique identifiers
    # so every auth worker gets it's own unique name. Then we use that name to
    # register the worker with the registry.
    id = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    name = ExecWorker.via_tuple(id)
    opts = ExecWorker.parse_opts(ctx) |> Keyword.put(:name, name)

    {:ok, _pid} =
      DynamicSupervisor.start_child(
        K8s.Conn.Auth.ProviderSupervisor,
        {ExecWorker, opts}
      )

    {:ok, %__MODULE__{target: name}}
  end

  def create(_, _), do: :skip

  defimpl K8s.Conn.RequestOptions, for: K8s.Conn.Auth.Exec do
    @doc """
    Generates HTTP Authorization options for
    auth-provider authentication by asking the running ExecWorker for a token.
    """
    @spec generate(Exec.t()) :: K8s.Conn.RequestOptions.generate_t()
    def generate(%Exec{target: target} = _provider) do
      with {:ok, token} <- ExecWorker.get_token(target) do
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
