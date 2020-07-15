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

  defstruct [:command, :env, :args]

  @type t :: %__MODULE__{
          command: String.t(),
          env: %{name: String.t(), value: String.t()},
          args: list(String.t())
        }

  @impl true
  def create(%{"exec" => %{"command" => command} = config}, _) do
    # Optional:
    args = Map.get(config, "args", [])
    env = Map.get(config, "env", [])

    %__MODULE__{
      command: command,
      env: format_env(env),
      args: args
    }
  end

  def create(_, _), do: nil

  defp format_env(env) when is_list(env), do: Enum.into(env, %{}, &format_env/1)
  defp format_env(%{"name" => key, "value" => value}), do: {key, value}

  defimpl K8s.Conn.RequestOptions, for: __MODULE__ do
    @doc "Generates HTTP Authorization options for auth-provider authentication"
    @spec generate(Exec.t()) :: K8s.Conn.RequestOptions.generate_t()
    def generate(%Exec{} = provider) do
      with {:ok, token} <- Exec.generate_token(provider) do
        {
          :ok,
          %K8s.Conn.RequestOptions{
            headers: [{"Authorization", "Bearer #{token}"}],
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
          {:ok, binary} | {:error, binary | atom, {:exec_fail, binary}}
  def generate_token(config) do
    with {cmd_response, 0} <- System.cmd(config.command, config.args, env: config.env),
         {:ok, data} <- Jason.decode(cmd_response),
         {:ok, token} when not is_nil(token) <- parse_cmd_response(data) do
      {:ok, token}
    else
      {cmd_response, err_code} when is_binary(cmd_response) and is_integer(err_code) ->
        {:error, {:exec_fail, cmd_response}}

      error ->
        error
    end
  end

  defp parse_cmd_response(%{"kind" => "ExecCredential", "status" => %{"token" => token}}),
    do: {:ok, token}

  #  # TODO: support clientKeyData and clientCertificateData
  #  defp parse_cmd_response(
  #         %{
  #           "kind" => "ExecCredential",
  #           "status" => %{
  #             "clientCertificateData" => _certData,
  #             "clientKeyData" => _keyData
  #           }
  #         }
  #       ), do: {:error, {:exec_fail, "Unsupported ExecCredential"}}

  defp parse_cmd_response(_), do: {:error, {:exec_fail, "Unsupported ExecCredential"}}
end
