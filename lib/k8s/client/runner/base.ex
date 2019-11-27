defmodule K8s.Client.Runner.Base do
  @moduledoc """
  Base HTTP processor for `K8s.Client`
  """

  @type result_t :: {:ok, map() | reference()} | {:error, atom} | {:error, binary()}

  alias K8s.Cluster
  alias K8s.Operation
  alias K8s.Middleware.Request

  @doc """
  Runs a `K8s.Operation`.

  ## Examples

  *Note:* Examples assume a cluster was registered named :test_cluster, see `K8s.Cluster.Registry.add/2`.

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
  @spec run(Operation.t(), atom | nil) :: result_t
  def run(%Operation{} = operation, cluster_name \\ :default),
    do: run(operation, cluster_name, [])

  @doc """
  Run an operation and pass `opts` to HTTPoison.
  Destructures `Operation` data and passes as the HTTP body.

  See `run/2`
  """
  @spec run(Operation.t(), atom, keyword()) :: result_t
  def run(%Operation{} = operation, cluster_name, opts) when is_list(opts) do
    run(operation, cluster_name, operation.data, opts)
  end

  @doc """
  Run an operation with an HTTP Body (map) and pass `opts` to HTTPoison.
  See `run/2`
  """
  @spec run(Operation.t(), atom, map(), keyword()) :: result_t
  def run(%Operation{} = operation, cluster, body, opts \\ []) do
    with req <- new_request(cluster, operation, body, opts),
         {:ok, url} <- Cluster.url_for(operation, cluster),
         # TODO: handle error return here type
         {:ok, req} <- apply_middleware(req) do
      K8s.http_provider().request(req.method, url, req.body, req.headers, req.opts)
    end
  end

  # TODO: handle error return here type
  @spec apply_middleware(Request.t()) :: {:ok, Request.t()}
  defp apply_middleware(req) do
    middlewares = K8s.Middleware.list(:request, req.cluster)

    # TODO: handle error return here type
    # case( K8s.Middleware.Request | K8s.Middleware.Error(mw, req, actual_error))

    updated_request =
      Enum.reduce_while(middlewares, req, fn middleware, req ->
        case apply(middleware, :call, [req]) do
          {:ok, updated_request} ->
            {:cont, updated_request}

          # TODO: handle error return here type
          _error ->
            {:halt, :handler_error_return_type_here}
        end
      end)

    {:ok, updated_request}
  end

  @spec new_request(atom(), K8s.Operation.t(), list(map()) | map() | binary() | nil, Keyword.t()) ::
          Request.t()
  defp new_request(cluster, %Operation{} = operation, body, opts) do
    req = %Request{cluster: cluster, method: operation.method, body: body}
    http_opts_params = build_http_params(opts[:params], operation.label_selector)
    opts_with_selector_params = Keyword.put(opts, :params, http_opts_params)

    http_opts = Keyword.merge(req.opts, opts_with_selector_params)
    %Request{req | opts: http_opts}
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
