defmodule K8s.Conn.Auth.AuthProvider do
  @moduledoc """
  `auth-provider` authentication support
  """
  alias K8s.Conn.Auth.AuthProvider
  alias K8s.Conn.Error
  alias K8s.Conn.RequestOptions
  @behaviour K8s.Conn.Auth

  defstruct [:cmd_path, :cmd_args, :token_key, :expiry_key]

  @type t :: %__MODULE__{
          cmd_path: String.t(),
          cmd_args: list(String.t()),
          token_key: list(String.t()),
          expiry_key: list(String.t())
        }

  @impl true
  @spec create(map, String.t()) :: {:ok, t} | :skip
  def create(
        %{
          "auth-provider" => %{
            "config" => %{
              "cmd-path" => cmd_path,
              "cmd-args" => cmd_args,
              "token-key" => token_key,
              "expiry-key" => expiry_key
            }
          }
        },
        _
      ) do
    {:ok,
     %__MODULE__{
       cmd_path: cmd_path,
       cmd_args: format_args(cmd_args),
       token_key: format_json_keys(token_key),
       expiry_key: format_json_keys(expiry_key)
     }}
  end

  def create(_, _), do: :skip

  @spec format_args(String.t()) :: list(String.t())
  defp format_args(args), do: String.split(args, " ")

  @spec format_json_keys(String.t()) :: list(String.t())
  defp format_json_keys(jsonpath) do
    jsonpath
    |> String.trim_leading("{.")
    |> String.trim_trailing("}")
    |> String.split(".")
  end

  defimpl RequestOptions, for: K8s.Conn.Auth.AuthProvider do
    @doc "Generates HTTP Authorization options for auth-provider authentication"
    @spec generate(AuthProvider.t()) :: RequestOptions.generate_t()
    def generate(%AuthProvider{} = provider) do
      case AuthProvider.generate_token(provider) do
        {:ok, token} ->
          {:ok,
           %RequestOptions{
             headers: [{:Authorization, "Bearer #{token}"}],
             ssl_options: []
           }}

        error ->
          error
      end
    end
  end

  @doc """
  "Generate" a token using the `auth-provider` config in kube config.
  """
  @spec generate_token(t) ::
          {:ok, binary} | {:error, :enoent | K8s.Conn.Error.t()}
  def generate_token(config) do
    with {cmd_response, 0} <- System.cmd(config.cmd_path, config.cmd_args),
         {:ok, data} <- Jason.decode(cmd_response),
         token when not is_nil(token) <- get_in(data, config.token_key) do
      {:ok, token}
    else
      {cmd_response, err_code} when is_binary(cmd_response) and is_integer(err_code) ->
        msg = "#{__MODULE__} failed: #{cmd_response}"
        {:error, %Error{message: msg}}

      error ->
        error
    end
  end
end
