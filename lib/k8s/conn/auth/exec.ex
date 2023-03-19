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
  alias K8s.Conn.Error

  defstruct [:command, :env, args: []]

  @type t :: %__MODULE__{
          command: String.t(),
          env: %{name: String.t(), value: String.t()},
          args: list(String.t())
        }

  @impl true
  @spec create(map() | any, String.t() | any) :: {:ok, t} | {:error, Error.t()} | :skip
  def create(%{"exec" => %{"command" => command} = config}, _) do
    # Optional:
    args = config["args"] |> List.wrap()
    env = config["env"] |> List.wrap() |> format_env()

    {:ok,
     %__MODULE__{
       command: command,
       env: env,
       args: args
     }}
  end

  def create(_, _), do: :skip

  @spec format_env(list()) :: map()
  defp format_env(env), do: Map.new(env, &{&1["name"], &1["value"]})

  defimpl K8s.Conn.RequestOptions, for: K8s.Conn.Auth.Exec do
    @doc "Generates HTTP Authorization options for auth-provider authentication"
    @spec generate(Exec.t()) :: K8s.Conn.RequestOptions.generate_t()
    def generate(%Exec{} = provider) do
      with {:ok, token} <- Exec.generate_token(provider) do
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

  @doc """
  "Generate" a token using the `exec` config in kube config.
  """
  @spec generate_token(t) ::
          {:ok, binary} | {:error, Jason.DecodeError.t() | Error.t()}
  def generate_token(config) do
    with {cmd_response, 0} <- System.cmd(config.command, config.args, env: config.env),
         {:ok, data} <- Jason.decode(cmd_response),
         {:ok, token} when not is_nil(token) <- parse_cmd_response(data) do
      {:ok, token}
    else
      {cmd_response, err_code} when is_binary(cmd_response) and is_integer(err_code) ->
        msg = "#{__MODULE__} failed: #{cmd_response}"
        {:error, %Error{message: msg}}

      error ->
        error
    end
  end

  @spec parse_cmd_response(map) :: {:ok, binary} | {:error, Error.t()}
  defp parse_cmd_response(%{"kind" => "ExecCredential", "status" => %{"token" => token}}),
    do: {:ok, token}

  defp parse_cmd_response(_) do
    msg = "#{__MODULE__} failed: Unsupported ExecCredential"
    {:error, %Error{message: msg}}
  end
end
