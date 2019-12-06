defmodule K8s.Client.Runner.Base do
  @moduledoc """
  Base HTTP processor for `K8s.Client`
  """

  @type result_t ::
          {:ok, map() | reference()}
          | {:error, K8s.Middleware.Error.t()}
          | {:error, :connection_not_registered}
          | {:error, :missing_required_param}
          | {:error, :unsupported_api_version}
          | {:error, binary()}

  @typedoc "Acceptable HTTP body types"
  @type body_t :: list(map()) | map() | binary() | nil

  @typedoc "Connection cluster name or `K8s.Conn`"
  @type cluster_or_conn_t :: atom() | K8s.Conn.t()

  alias K8s.Cluster
  alias K8s.Conn
  alias K8s.Operation
  alias K8s.Middleware.Request

  @doc """
  Runs a `K8s.Operation`.

  ## Examples

  *Note:* Examples assume a `K8s.Conn` was configured named `:test_cluster`. See `K8s.Conn.Config`.

  Running a list pods operation:

  ```elixir
  operation = K8s.Client.list("v1", "Pod", namespace: :all)
  {:ok, %{"items" => pods}} = K8s.Client.run(operation, :test_cluster)
  ```

  Running a dry-run of a create deployment operation:

  ```elixir
  deployment = %{
    "apiVersion" => "apps/v1",
    "kind" => "Deployment",
    "metadata" => %{
      "labels" => %{
        "app" => "nginx"
      },
      "name" => "nginx",
      "namespace" => "test"
    },
    "spec" => %{
      "replicas" => 2,
      "selector" => %{
        "matchLabels" => %{
          "app" => "nginx"
        }
      },
      "template" => %{
        "metadata" => %{
          "labels" => %{
            "app" => "nginx"
          }
        },
        "spec" => %{
          "containers" => %{
            "image" => "nginx",
            "name" => "nginx"
          }
        }
      }
    }
  }

  operation = K8s.Client.create(deployment)

  # opts is passed to HTTPoison as opts.
  opts = [params: %{"dryRun" => "all"}]
  :ok = K8s.Client.Runner.Base.run(operation, :test_cluster, opts)
  ```
  """
  @spec run(Operation.t(), cluster_or_conn_t | nil) :: result_t
  def run(%Operation{} = operation, cluster_name_or_conn \\ :default),
    do: run(operation, cluster_name_or_conn, [])

  @doc """
  Run an operation and pass `opts` to HTTPoison.
  Destructures `Operation` data and passes as the HTTP body.

  See `run/2`
  """
  @spec run(Operation.t(), cluster_or_conn_t, keyword()) :: result_t
  def run(%Operation{} = operation, cluster_name_or_conn, opts) when is_list(opts) do
    run(operation, cluster_name_or_conn, operation.data, opts)
  end

  def run(operation, cluster_name_or_conn, body, opts \\ [])

  @doc """
  Run an operation with an HTTP Body (map) and pass `opts` to HTTPoison.
  See `run/2`
  """
  @spec run(Operation.t(), atom, map(), keyword()) :: result_t
  def run(%Operation{} = operation, cluster_name, body, opts) do
    with {:ok, conn} <- Conn.lookup(cluster_name) do
      run(operation, conn, body, opts)
    end
  end

  @doc """
  Run an operation with an HTTP Body (map) and pass `opts` to HTTPoison.
  See `run/2`
  """
  @spec run(Operation.t(), Conn.t(), map(), keyword()) :: result_t
  def run(%Operation{} = operation, %Conn{} = conn, body, opts) do
    with {:ok, url} <- Cluster.url_for(operation, conn),
         req <- new_request(conn, url, operation, body, opts),
         {:ok, req} <- K8s.Middleware.run(req) do
      K8s.http_provider().request(req.method, req.url, req.body, req.headers, req.opts)
    end
  end

  @spec new_request(Conn.t(), String.t(), K8s.Operation.t(), body_t, Keyword.t()) ::
          Request.t()
  defp new_request(conn, url, %Operation{} = operation, body, opts) do
    req = %Request{conn: conn, method: operation.method, body: body}
    http_opts_params = build_http_params(opts[:params], operation.label_selector)
    opts_with_selector_params = Keyword.put(opts, :params, http_opts_params)

    http_opts = Keyword.merge(req.opts, opts_with_selector_params)
    %Request{req | opts: http_opts, url: url}
  end

  @spec build_http_params(nil | keyword | map, nil | K8s.Selector.t()) :: map()
  defp build_http_params(nil, nil), do: %{}
  defp build_http_params(nil, %K8s.Selector{} = s), do: %{labelSelector: K8s.Selector.to_s(s)}
  defp build_http_params(params, nil), do: params

  defp build_http_params(params, %K8s.Selector{} = s) when is_list(params),
    do: params |> Enum.into(%{}) |> build_http_params(s)

  # Supplying a `labelSelector` to `run/4 should take precedence
  defp build_http_params(params, %K8s.Selector{} = s) when is_map(params) do
    from_operation = %{labelSelector: K8s.Selector.to_s(s)}
    Map.merge(from_operation, params)
  end
end
