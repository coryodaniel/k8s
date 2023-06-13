defmodule K8s.Conn do
  @moduledoc ~S"""
  Handles authentication and connection configuration details for a Kubernetes
  cluster. The `%K8s.Conn{}` struct is required in order to run any object
  against the cluster. Use any of the functions defined in this module to create
  a `%K8s.Conn{}` struct and pass it to the functions of `K8s.Client`.

  ## Example

  ```
  {:ok, conn} = K8s.Conn.from_file("~/.kube/config")

  {:ok, default_ns} =
    K8s.Client.get("v1", "Namespace", name: "default")
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run()
  ```

  Alternatively, you can pass `conn` to `K8s.Client.run()`.

  ```
  {:ok, conn} = K8s.Conn.from_file("~/.kube/config")
  op = K8s.Client.get("v1", "Namespace", name: "default")
  {:ok, default_ns} = K8s.Client.run(op, conn)
  ```

  ## Scenarios

  * If your cluster connection is defined in a file, e.g. `~/.kube/config`, use
    `K8s.Conn.from_file/2`.
  * If running in a pod inside the cluster you're connecting to, use
    `K8s.Conn.from_service_account/2`
  * If an environment variable points to a config file, use
    `K8s.Conn.from_env/2`
  """

  alias __MODULE__
  alias K8s.Conn.{PKI, RequestOptions}
  alias K8s.Resource.NamedList
  require Logger

  @default_service_account_path "/var/run/secrets/kubernetes.io/serviceaccount"
  @default_env_variable "KUBECONFIG"

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
            http_provider: K8s.default_http_provider(),
            cacertfile: K8s.default_cacertfile()

  @typedoc ~S"""
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
          http_provider: module(),
          cacertfile: String.t()
        }

  @doc ~S"""
  Reads configuration details from a kubernetes config file.

  If you run your code on your machine, you most likely have a config file at
  `~/.kube/config`. If you created a local cluster using `kind`, `k3d` or
  similar, a context entry is either added to that config file or you saved it
  to a specific location upon cluster creation. Either way, this function reads
  the config from any of these files.

  ### Example

  Using the currently selected context:

  ```
  {:ok, conn} = K8s.Conn.from_file("~/.kube/config")
  ```

  Pass the context and allow insecure TLS verification :

  ```
  {:ok, conn} =
    K8s.Conn.from_file("~/.kube/config",
      context: "my-kind-cluster",
      insecure_skip_tls_verify: true
    )
  ```

  ### Options

  * `:context` - sets an alternate context - defaults to `current-context`.
  * `:cluster` - set or override the cluster read from the context
  * `:user`-  set or override the user read from the context
  * `:discovery_driver` - module name to use for discovery
  * `:discovery_opts` - options for discovery module
  * `:insecure_skip_tls_verify` - Skip TLS verification
  """
  @spec from_file(binary, keyword) ::
          {:ok, __MODULE__.t()} | {:error, :enoent | K8s.Conn.Error.t()}
  def from_file(config_file, opts \\ []) do
    abs_config_file = Path.expand(config_file)
    base_path = Path.dirname(abs_config_file)

    with {:ok, config} <- YamlElixir.read_from_file(abs_config_file),
         context_name <- opts[:context] || config["current-context"],
         {:ok, context} <- find_configuration(config["contexts"], context_name, "context"),
         user_name <- opts[:user] || context["user"],
         {:ok, user} <- find_configuration(config["users"], user_name, "user"),
         cluster_name <- opts[:cluster] || context["cluster"],
         {:ok, cluster} <- find_configuration(config["clusters"], cluster_name, "cluster"),
         {:ok, cert} <- PKI.cert_from_map(cluster, base_path) do
      insecure_skip_tls_verify =
        Keyword.get(opts, :insecure_skip_tls_verify, cluster["insecure-skip-tls-verify"])

      conn = %Conn{
        cluster_name: cluster_name,
        user_name: user_name,
        url: cluster["server"],
        ca_cert: cert,
        auth: get_auth(user, base_path),
        insecure_skip_tls_verify: insecure_skip_tls_verify
      }

      {:ok, maybe_update_defaults(conn, opts)}
    else
      error -> error
    end
  end

  @doc ~S"""
  Generates the configuration from a Kubernetes service account.

  This is used when running in a Pod inside the cluster you're accessing. Make
  sure to setup RBAC for the service account running the Pod.

  Documentation: [kubernetes.io :: Accessing the API from a
  Pod](https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#accessing-the-api-from-a-pod)

  ### Options

  * `:insecure_skip_tls_verify` - Skip TLS verification

  ### Example

  Using the currently selected context:

  ```
  {:ok, conn} = K8s.Conn.from_service_account()
  ```

  You can set a specific path to the service account token file:

  ```
  {:ok, conn} =
    K8s.Conn.from_service_account("/path/to/token",
      insecure_skip_tls_verify: true
    )
  ```

  Allow insecure TLS verification:

  ```
  {:ok, conn} =
    K8s.Conn.from_service_account(
      insecure_skip_tls_verify: true
    )
  ```

  ```
  {:ok, conn} =
    K8s.Conn.from_service_account(
      "/path/to/token",
      insecure_skip_tls_verify: true
    )
  ```
  """
  @spec from_service_account(service_account_path :: String.t(), opts :: Keyword.t()) ::
          {:ok, t()} | {:error, :enoent | K8s.Conn.Error.t()}
  def from_service_account(service_account_path, opts) do
    cert_path = Path.join(service_account_path, "ca.crt")
    token_path = Path.join(service_account_path, "token")
    insecure_skip_tls_verify = Keyword.get(opts, :insecure_skip_tls_verify, false)

    with {:ok, token} <- File.read(token_path),
         {:ok, ca_cert} <- PKI.cert_from_pem(cert_path) do
      conn = %Conn{
        url: kubernetes_service_url(),
        ca_cert: ca_cert,
        auth: %K8s.Conn.Auth.Token{token: token},
        insecure_skip_tls_verify: insecure_skip_tls_verify
      }

      {:ok, conn}
    else
      error -> error
    end
  end

  @doc false
  @spec from_service_account(opts_or_sa_path :: String.t() | Keyword.t()) ::
          {:ok, t()} | {:error, :enoent | K8s.Conn.Error.t()}
  def from_service_account(opts) when is_list(opts) do
    from_service_account(@default_service_account_path, opts)
  end

  @doc false
  def from_service_account(service_account_path) when is_binary(service_account_path) do
    from_service_account(service_account_path, [])
  end

  @doc false
  @spec from_service_account() ::
          {:ok, t()} | {:error, :enoent | K8s.Conn.Error.t()}
  def from_service_account do
    from_service_account(@default_service_account_path, [])
  end

  @doc ~S"""
  Generates the configuration from a file whose location is defined by the
  given `env_var`. Defaults to `KUBECONFIG`.

  ### Options

  See `from_file/2`.

  ### Examples

  if `KUBECONFIG` is set:

  ```
  {:ok, conn} = K8s.Conn.from_env()
  ```

  Pass the env variable name:

  ```
  {:ok, conn} = K8s.Conn.from_env("TEST_KUBECONFIG")
  ```

  Pass the env variable name and options:

  ```
  {:ok, conn} = K8s.Conn.from_env("TEST_KUBECONFIG", insecure_skip_tls_verify: true)
  ```
  """
  @spec from_env(env_variable :: binary(), opts :: keyword()) ::
          {:ok, t()} | {:error, :enoent | K8s.Conn.Error.t()}
  def from_env(env_variable, opts) do
    case System.get_env(env_variable) do
      nil ->
        {:error, %K8s.Conn.Error{message: ~s(Env variable "#{env_variable}" not declared)}}

      config_file ->
        from_file(config_file, opts)
    end
  end

  @doc false
  @spec from_env(opts :: binary() | keyword()) ::
          {:ok, t()} | {:error, :enoent | K8s.Conn.Error.t()}
  def from_env(env_var_or_opts) when is_list(env_var_or_opts),
    do: from_env(@default_env_variable, env_var_or_opts)

  @doc false
  def from_env(env_var_or_opts) when is_binary(env_var_or_opts), do: from_env(env_var_or_opts, [])

  @doc false
  @spec from_env() :: {:ok, t()} | {:error, :enoent | K8s.Conn.Error.t()}
  def from_env, do: from_env(@default_env_variable, [])

  @spec find_configuration([map()], String.t(), String.t()) ::
          {:ok, map()} | {:error, K8s.Conn.Error.t()}
  defp find_configuration(items, name, type) do
    case get_in(items, [NamedList.access(name), type]) do
      nil ->
        err = %K8s.Conn.Error{
          message: "Error parsing kube config. No `#{type}` type found with name: '#{name}'"
        }

        {:error, err}

      item ->
        {:ok, item}
    end
  end

  @spec maybe_update_defaults(Conn.t(), keyword()) :: Conn.t()
  defp maybe_update_defaults(conn, opts) do
    struct!(conn, Keyword.take(opts, [:discovery_driver, :discovery_opts, :http_provider]))
  end

  @doc false
  @spec resolve_file_path(binary, binary) :: binary
  def resolve_file_path(file_name, base_path) do
    case Path.type(file_name) do
      :absolute -> file_name
      _ -> Path.join([base_path, file_name])
    end
  end

  @spec get_auth(map, binary) :: auth_t
  defp get_auth(%{} = auth_map, base_path) do
    Enum.find_value(auth_providers(), fn provider ->
      case provider.create(auth_map, base_path) do
        {:ok, auth} ->
          auth

        {:error, error} ->
          Logger.debug(
            "Provider (#{provider}) failed to generate auth, skipping. #{error}",
            library: :k8s
          )

          nil

        :skip ->
          nil
      end
    end)
  end

  @spec auth_providers() :: list(atom)
  defp auth_providers do
    Application.get_env(:k8s, :auth_providers, []) ++ @auth_providers
  end

  @spec kubernetes_service_url :: String.t()
  defp kubernetes_service_url do
    host = System.get_env("KUBERNETES_SERVICE_HOST")
    port = System.get_env("KUBERNETES_SERVICE_PORT")
    "https://#{host}:#{port}"
  end

  defimpl K8s.Conn.RequestOptions, for: K8s.Conn do
    @doc "Generates HTTP Authorization options for certificate authentication"
    @spec generate(K8s.Conn.t()) :: K8s.Conn.RequestOptions.generate_t()
    def generate(%K8s.Conn{} = conn) do
      case RequestOptions.generate(conn.auth) do
        {:ok, %RequestOptions{headers: headers, ssl_options: auth_options}} ->
          verify_options =
            case conn.insecure_skip_tls_verify do
              true -> [verify: :verify_none]
              _ -> [verify: :verify_peer]
            end

          ca_options =
            case conn.ca_cert do
              nil -> [cacertfile: conn.cacertfile |> String.to_charlist()]
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
