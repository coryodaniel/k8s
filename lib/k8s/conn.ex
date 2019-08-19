defmodule K8s.Conn do
  @moduledoc """
  Handles authentication and connection configuration details for a Kubernetes cluster.
  """

  alias __MODULE__
  alias K8s.Conn.{PKI, RequestOptions}

  @providers [
    K8s.Conn.Auth.Certificate,
    K8s.Conn.Auth.Token,
    K8s.Conn.Auth.AuthProvider
  ]

  @typep auth_t :: nil | struct
  defstruct cluster_name: nil,
            user_name: nil,
            url: "",
            insecure_skip_tls_verify: false,
            ca_cert: nil,
            auth: nil

  @type t :: %__MODULE__{
          cluster_name: String.t() | nil,
          user_name: String.t() | nil,
          url: String.t(),
          insecure_skip_tls_verify: boolean(),
          ca_cert: String.t() | nil,
          auth: auth_t
        }

  @doc """
  Reads configuration details from a kubernetes config file.

  Defaults to `current-context`.

  ### Options

  * `context` sets an alternate context
  * `cluster` set or override the cluster read from the context
  * `user` set or override the user read from the context
  """
  @spec from_file(binary, keyword) :: K8s.Conn.t()
  def from_file(config_file, opts \\ []) do
    abs_config_file = Path.expand(config_file)
    base_path = Path.dirname(abs_config_file)

    config = YamlElixir.read_from_file!(abs_config_file)
    context_name = opts[:context] || config["current-context"]
    context = find_by_name(config["contexts"], context_name, "context")

    user_name = opts[:user] || context["user"]
    user = find_by_name(config["users"], user_name, "user")

    cluster_name = opts[:cluster] || context["cluster"]
    cluster = find_by_name(config["clusters"], cluster_name, "cluster")

    %Conn{
      cluster_name: cluster_name,
      user_name: user_name,
      url: cluster["server"],
      ca_cert: PKI.cert_from_map(cluster, base_path),
      auth: get_auth(user, base_path),
      insecure_skip_tls_verify: cluster["insecure-skip-tls-verify"]
    }
  end

  @doc """
  Generates configuration from kubernetes service account

  ## Links

  [kubernetes.io :: Accessing the API from a Pod](https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#accessing-the-api-from-a-pod)
  """

  @spec from_service_account() :: K8s.Conn.t()
  def from_service_account(),
    do: from_service_account("/var/run/secrets/kubernetes.io/serviceaccount")

  @spec from_service_account(String.t()) :: K8s.Conn.t()
  def from_service_account(root_sa_path) do
    host = System.get_env("KUBERNETES_SERVICE_HOST")
    port = System.get_env("KUBERNETES_SERVICE_PORT")
    cert_path = Path.join(root_sa_path, "ca.crt")
    token_path = Path.join(root_sa_path, "token")

    %Conn{
      url: "https://#{host}:#{port}",
      ca_cert: PKI.cert_from_pem(cert_path),
      auth: %K8s.Conn.Auth.Token{token: File.read!(token_path)}
    }
  end

  @spec find_by_name([map()], String.t(), String.t()) :: map()
  defp find_by_name(items, name, type) do
    items
    |> Enum.find(fn item -> item["name"] == name end)
    |> Map.get(type)
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
    Application.get_env(:k8s, :auth_providers, []) ++ @providers
  end

  defimpl K8s.Conn.RequestOptions, for: __MODULE__ do
    @doc "Generates HTTP Authorization options for certificate authentication"
    @spec generate(K8s.Conn.t()) :: K8s.Conn.RequestOptions.generate_t()
    def generate(%K8s.Conn{} = conf) do
      case RequestOptions.generate(conf.auth) do
        {:ok, %RequestOptions{headers: headers, ssl_options: auth_options}} ->
          verify_options =
            case conf.insecure_skip_tls_verify do
              true -> [verify: :verify_none]
              _ -> []
            end

          ca_options =
            case conf.ca_cert do
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
