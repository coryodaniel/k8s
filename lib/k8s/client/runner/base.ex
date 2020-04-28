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
  alias K8s.Operation
  alias K8s.Middleware.Request
  alias K8s.Conn.RequestOptions
  alias K8s.Discovery


  require Logger

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

  operation = 
    deployment 
    |> K8s.Client.create()
    |> K8s.Operation.put_query_param(:dryRun, "all")

  {:ok, conn} = K8s.Conn.lookup(:test)  
  {:ok, result} = K8s.Client.Runner.Base.run(operation, conn)
  ```
  """
  @spec run(Operation.t(), Conn.t() | nil) :: result_t
  def run(%Operation{} = operation, %Conn{} = conn),
    do: run(operation, conn, [])

  @doc """
  Run an connect operation and pass `query_params` and `opts` to Websocket provider.

  The query params inside %Operation{} must be a Keyword list.

  """
  @spec run(Operation.t(), Conn.t(), keyword()) :: result_t
  def run(%Operation{verb: :connect} = operation, %Conn{} = conn, opts) when is_list(opts) do
    with {:ok, url} <- Discovery.url_for(conn, operation),
         req <- new_request(conn, url, operation, [], opts),
         {:ok, request_options} <- RequestOptions.generate(conn) do

      ## headers for websocket connection to k8s API
      headers =
        request_options.headers ++ [{"Accept", "*/*"}, {"Content-Type", "application/json"}]

      cacerts = Keyword.get(request_options.ssl_options, :cacerts)
      query_params = "?#{URI.encode_query(req.opts[:params])}"

      url = URI.merge(req.url, query_params)
      K8s.websocket_provider().request(url, false, request_options.ssl_options, cacerts, headers, opts)
    else
      {:error, message} -> {:error, message}
      error -> {:error, inspect(error)}
    end
  end

  def run(%Operation{} = operation, %Conn{} = conn, opts) when is_list(opts) do
    run(operation, conn, operation.data, opts)
  end


  @doc """
  Run an operation with an HTTP Body (map) and pass `opts` to HTTPoison.
  See `run/2`
  """
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
  defp maybe_get_deprecated_label_selector(new_label_selector, deprecated_label_selector) do
    case deprecated_label_selector do
      nil ->
        new_label_selector

      deprecated_label_selector ->
        Logger.warn(
          "K8s.Operation label_selector is deprecated. Use K8s.Selector functions instead."
        )

        deprecated_label_selector
    end
  end

  @spec merge_deprecated_params(nil | map(), nil | map()) :: map() | keyword()
  # covers when both op_params and run_params are nil
  defp merge_deprecated_params(nil, nil), do: %{}
  # covers when op_params are nil
  defp merge_deprecated_params(nil, run_params), do: merge_deprecated_params(%{}, run_params)
  # covers when there is not run_params
  defp merge_deprecated_params(op_params, nil) do
    op_params
  end

  defp merge_deprecated_params(%{} = op_params, run_params) do
    Logger.warn(
      "Providing HTTPoison options to K8s.Client.Runner.Base.run/N is deprecated. Use K8s.Operation's query_params key intead."
    )

    run_params_as_map = Enum.into(run_params, %{})
    Map.merge(op_params, run_params_as_map)
  end

  @spec build_http_params(keyword | map, nil | K8s.Selector.t()) :: map()
  # defp build_http_params(nil, nil), do: %{}  
  # for Pod connect
  defp build_http_params(params, nil) when is_list(params) do
    process_opts(params)
    |> Keyword.drop([:stream_to])
  end
  defp build_http_params(params, nil), do: Enum.into(params, %{})  
  
  # Supplying a `labelSelector` to `run/4 should take precedence
  defp build_http_params(params, %K8s.Selector{} = s) do
    # After HTTPoison options are removed from run/N, this will always be a map()
    params_as_map = Enum.into(params, %{})
    Map.merge(params_as_map, %{labelSelector: K8s.Selector.to_s(s)})
  end

  # for Pod connect
  defp process_opts(opts) do
    default = [stdin: true, stdout: true, stderr: true, tty: true]
    Keyword.merge(default, opts)
  end

end
