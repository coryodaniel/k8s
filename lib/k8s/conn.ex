defmodule K8s.Conn do
  @moduledoc """
  Handles authentication and connection configuration details for a Kubernetes cluster.
  """

  alias __MODULE__
  alias K8s.Conn.{PKI, RequestOptions}
  alias K8s.Resource.NamedList
  require Logger

  @default_service_account_path "/var/run/secrets/kubernetes.io/serviceaccount"

  @auth_providers [
    K8s.Conn.Auth.Certificate,
    K8s.Conn.Auth.Token,
    K8s.Conn.Auth.AuthProvider,
    K8s.Conn.Auth.Exec,
    K8s.Conn.Auth.BasicAuth
  ]

  @typep auth_t :: nil | struct
  defstruct cluster_name: nil,
            user_name: nil,
            url: "",
            insecure_skip_tls_verify: false,
            ca_cert: nil,
            auth: nil,
            middleware: K8s.Middleware.Stack.default(),
            discovery_driver: K8s.default_discovery_driver(),
            discovery_opts: K8s.default_discovery_opts(),
            http_provider: K8s.default_http_provider()

  @typedoc """
  * `cluster_name` - The cluster name if read from a kubeconfig file
  * `user_name` - The user name if read from a kubeconfig file
  * `url` - The Kubernetes API URL
  """
  @type t :: %__MODULE__{
          cluster_name: String.t() | nil,
          user_name: String.t() | nil,
          url: String.t(),
          insecure_skip_tls_verify: boolean(),
          ca_cert: String.t() | nil,
          auth: auth_t,
          middleware: K8s.Middleware.Stack.t(),
          discovery_driver: module(),
          discovery_opts: Keyword.t(),
          http_provider: module()
        }

  @doc """
  Reads configuration details from a kubernetes config file.

  Defaults to `current-context`.

  ### Options

  * `context` sets an alternate context
  * `cluster` set or override the cluster read from the context
  * `user` set or override the user read from the context
  * `discovery_driver` module name to use for discovery
  * `discovery_opts` options for discovery module
  """
  @spec from_file(binary, keyword) :: {:ok, __MODULE__.t()} | {:error, atom()}
  def from_file(config_file, opts \\ []) do
    abs_config_file = Path.expand(config_file)
    base_path = Path.dirname(abs_config_file)

    with {:ok, config} <- YamlElixir.read_from_file(abs_config_file),
         context_name <- opts[:context] || config["current-context"],
         {:ok, context} <- find_configuration(config["contexts"], context_name, "context"),
         user_name <- opts[:user] || context["user"],
         {:ok, user} <- find_configuration(config["users"], user_name, "user"),
         cluster_name <- opts[:cluster] || context["cluster"],
         {:ok, cluster} <- find_configuration(config["clusters"], cluster_name, "cluster") do
      conn = %Conn{
        cluster_name: cluster_name,
        user_name: user_name,
        url: cluster["server"],
        ca_cert: PKI.cert_from_map(cluster, base_path),
        auth: get_auth(user, base_path),
        insecure_skip_tls_verify: cluster["insecure-skip-tls-verify"]
      }

      {:ok, maybe_update_defaults(conn, config)}
    else
      error -> error
    end
  end

  @doc """
  Generates configuration from kubernetes service account.

  ## Links

  [kubernetes.io :: Accessing the API from a Pod](https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#accessing-the-api-from-a-pod)
  """
  @spec from_service_account :: {:ok, __MODULE__.t()} | {:error, atom()}
  def from_service_account do
    from_service_account(@default_service_account_path)
  end

  @spec from_service_account(String.t()) :: {:ok, __MODULE__.t()} | {:error, atom()}
  def from_service_account(service_account_path) do
    cert_path = Path.join(service_account_path, "ca.crt")
    token_path = Path.join(service_account_path, "token")

    case File.read(token_path) do
      {:ok, token} ->
        # Open Issue #97: PKI.cert_from_pem/1 will raise an exception if the file is not present.
        ca_cert = PKI.cert_from_pem(cert_path)

        conn = %Conn{
          url: kubernetes_service_url(),
          ca_cert: ca_cert,
          auth: %K8s.Conn.Auth.Token{token: token}
        }

        {:ok, conn}

      error ->
        error
    end
  end

  @spec find_configuration([map()], String.t(), String.t()) ::
          {:ok, map()} | {:error, :invalid_configuration, String.t()}
  defp find_configuration(items, name, type) do
    case get_in(items, [NamedList.access(name), type]) do
      nil ->
        Logger.error("No `#{type}` type found with name: '#{name}'")
        {:error, :invalid_configuration}

      item ->
        {:ok, item}
    end
  end

  @spec maybe_update_defaults(Conn.t(), map()) :: Conn.t()
  defp maybe_update_defaults(%Conn{} = conn, config) do
    defaults = [:discovery_driver, :discovery_opts, :http_provider]

    Enum.reduce(defaults, conn, fn k, conn ->
      conn_value = Map.get(conn, k)
      config_value = Map.get(config, k)
      %{conn | k => config_value || conn_value}
    end)
  end

  @doc false
  @spec resolve_file_path(binary, binary) :: binary
  def resolve_file_path(file_name, base_path) do
    case Path.type(file_name) do
      :absolute -> file_name
      _ -> Path.join([base_path, file_name])
    end
  end

  @spec get_auth(map(), String.t()) :: auth_t
  defp get_auth(%{} = auth_map, base_path) do
    Enum.find_value(providers(), fn provider -> provider.create(auth_map, base_path) end)
  end

  @spec providers() :: list(atom)
  defp providers do
    Application.get_env(:k8s, :auth_providers, []) ++ @auth_providers
  end

  @spec kubernetes_service_url :: String.t()
  defp kubernetes_service_url do
    host = System.get_env("KUBERNETES_SERVICE_HOST")
    port = System.get_env("KUBERNETES_SERVICE_PORT")
    "https://#{host}:#{port}"
  end

  defimpl K8s.Conn.RequestOptions, for: __MODULE__ do
    @doc "Generates HTTP Authorization options for certificate authentication"
    @spec generate(K8s.Conn.t()) :: K8s.Conn.RequestOptions.generate_t()
    def generate(%K8s.Conn{} = conn) do
      case RequestOptions.generate(conn.auth) do
        {:ok, %RequestOptions{headers: headers, ssl_options: auth_options}} ->
          verify_options =
            case conn.insecure_skip_tls_verify do
              true -> [verify: :verify_none]
              _ -> []
            end

          ca_options =
            case conn.ca_cert do
              nil -> []
              cert -> [cacerts: [cert]]
            end

          {:ok,
           %RequestOptions{
             headers: headers,
             ssl_options: auth_options ++ verify_options ++ ca_options
           }}

        error ->
          error
      end
    end
  end
end
