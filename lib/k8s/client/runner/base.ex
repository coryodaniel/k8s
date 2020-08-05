defmodule K8s.Client.Runner.Base do
  @moduledoc """
  Base HTTP processor for `K8s.Client`
  """

  @type result_t ::
          {:ok, map() | reference()}
          | {:error, K8s.Middleware.Error.t()}
          | {:error, :connection_not_registered}
          | {:error, :missing_required_param}
          | {:error, atom()}
          | {:error, binary()}

  @typedoc "Acceptable HTTP body types"
  @type body_t :: list(map()) | map() | binary() | nil

  alias K8s.Conn
  alias K8s.Middleware.Request
  alias K8s.Operation

  require Logger

  @doc """
  Runs a `K8s.Operation`.

  ## Examples

  *Note:* Examples assume a `K8s.Conn` was configured named `"test"`. See `K8s.Conn.Config`.

  Running a list pods operation:

  ```elixir
  {:ok, conn} = K8s.Conn.lookup("test")
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

  operation =
    deployment
    |> K8s.Client.create()
    |> K8s.Operation.put_query_param(:dryRun, "all")

  {:ok, conn} = K8s.Conn.lookup("test")
  {:ok, result} = K8s.Client.Runner.Base.run(operation, conn)
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
      conn.http_provider.request(req.method, req.url, req.body, req.headers, req.opts)
    end
  end

  @spec new_request(Conn.t(), String.t(), K8s.Operation.t(), body_t, Keyword.t()) ::
          Request.t()
  defp new_request(%Conn{} = conn, url, %Operation{} = operation, body, opts) do
    req = %Request{conn: conn, method: operation.method, body: body}

    params = merge_deprecated_params(operation.query_params, opts[:params])

    # if label_selector is set, the end user is setting it manually, respect that value until removed in #73
    label_selector =
      maybe_get_deprecated_label_selector(params[:labelSelector], operation.label_selector)

    http_opts_params = build_http_params(params, label_selector)

    opts_with_selector_params = Keyword.put(opts, :params, http_opts_params)
    http_opts = Keyword.merge(req.opts, opts_with_selector_params)

    %Request{req | opts: http_opts, url: url}
  end

  @spec maybe_get_deprecated_label_selector(K8s.Selector.t() | nil, K8s.Selector.t() | nil) ::
          K8s.Selector.t() | nil
  defp maybe_get_deprecated_label_selector(new_label_selector, nil), do: new_label_selector

  @deprecated "K8s.Operation label_selector is deprecated. Use K8s.Selector functions instead."
  defp maybe_get_deprecated_label_selector(nil, deprecated_label_selector),
    do: deprecated_label_selector

  @spec merge_deprecated_params(map(), nil | map()) :: map()
  defp merge_deprecated_params(op_params, nil), do: op_params

  @deprecated "Providing HTTPoison options to K8s.Client.Runner.Base.run/N is deprecated. Use K8s.Operation's query_params key instead."
  defp merge_deprecated_params(%{} = op_params, run_params) do
    run_params_as_map = Enum.into(run_params, %{})
    Map.merge(op_params, run_params_as_map)
  end

  @spec build_http_params(keyword | map, nil | K8s.Selector.t()) :: map()
  defp build_http_params(params, nil), do: Enum.into(params, %{})

  # Supplying a `labelSelector` to `run/4 should take precedence
  defp build_http_params(params, %K8s.Selector{} = s) do
    # After HTTPoison options are removed from run/N, this will always be a map()
    params_as_map = Enum.into(params, %{})
    Map.merge(params_as_map, %{labelSelector: K8s.Selector.to_s(s)})
  end
end
