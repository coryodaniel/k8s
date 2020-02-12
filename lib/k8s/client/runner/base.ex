defmodule K8s.Client.Runner.Base do
  @moduledoc """
  Base HTTP processor for `K8s.Client`
  """

  @type result_t ::
          {:ok, map() | reference()}
          | {:error, K8s.Middleware.Error.t()}
          | {:error, :connection_not_registered}
          | {:error, :missing_required_param}
          | {:error, binary()}

  @typedoc "Acceptable HTTP body types"
  @type body_t :: list(map()) | map() | binary() | nil

  alias K8s.Conn
  alias K8s.Operation
  alias K8s.Middleware.Request

  @doc """
  Runs a `K8s.Operation`.

  ## Examples

  *Note:* Examples assume a `K8s.Conn` was configured named `:test`. See `K8s.Conn.Config`.

  Running a list pods operation:

  ```elixir
  {:ok, conn} = K8s.Conn.lookup(:test)
  operation = K8s.Client.list("v1", "Pod", namespace: :all)
  {:ok, %{"items" => pods}} = K8s.Client.run(operation, conn)
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
  {:ok, conn} = K8s.Conn.lookup(:test)

  # opts is passed to HTTPoison as opts.
  opts = [params: %{"dryRun" => "all"}]
  :ok = K8s.Client.Runner.Base.run(operation, conn, opts)
  ```
  """
  @spec run(Operation.t(), Conn.t() | nil) :: result_t
  def run(%Operation{} = operation, %Conn{} = conn),
    do: run(operation, conn, [])

  @doc """
  Run an operation and pass `opts` to HTTPoison.
  Destructures `Operation` data and passes as the HTTP body.

  See `run/2`
  """
  @spec run(Operation.t(), Conn.t(), keyword()) :: result_t
  def run(%Operation{} = operation, %Conn{} = conn, opts) when is_list(opts) do
    run(operation, conn, operation.data, opts)
  end

  @doc """
  Run an operation with an HTTP Body (map) and pass `opts` to HTTPoison.
  See `run/2`
  """
  @spec run(Operation.t(), Conn.t(), map(), keyword()) :: result_t
  def run(%Operation{} = operation, %Conn{} = conn, body, opts \\ []) do
    with {:ok, url} <- K8s.Discovery.url_for(conn, operation),
         req <- new_request(conn, url, operation, body, opts),
         {:ok, req} <- K8s.Middleware.run(req) do
      K8s.http_provider().request(req.method, req.url, req.body, req.headers, req.opts)
    end
  end

  @spec new_request(Conn.t(), String.t(), K8s.Operation.t(), body_t, Keyword.t()) ::
          Request.t()
  defp new_request(%Conn{} = conn, url, %Operation{} = operation, body, opts) do
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
