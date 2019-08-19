defmodule K8s.Client.Runner.Base do
  @moduledoc """
  Base HTTP processor for `K8s.Client`
  """

  @type result_t :: {:ok, map() | reference()} | {:error, atom} | {:error, binary()}

  alias K8s.Cluster
  alias K8s.Conn.RequestOptions
  alias K8s.Operation

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

  See `run/2`
  """
  @spec run(Operation.t(), binary | atom, keyword()) :: result_t
  def run(%Operation{} = operation, cluster_name, opts) when is_list(opts) do
    run(operation, cluster_name, operation.data, opts)
  end

  @doc """
  Run an operation with an alternative HTTP Body (map) and pass `opts` to HTTPoison.
  See `run/2`
  """
  @spec run(Operation.t(), atom, map(), keyword()) :: result_t
  def run(%Operation{} = operation, cluster_name, body, opts \\ []) do
    with {:ok, url} <- Cluster.url_for(operation, cluster_name),
         {:ok, conf} <- Cluster.conf(cluster_name),
         {:ok, request_options} <- RequestOptions.generate(conf),
         {:ok, http_body} <- encode(body, operation.method) do
      http_headers = K8s.http_provider().headers(operation.method, request_options)

      http_opts_params = build_http_params(opts[:params], operation.label_selector)
      opts_with_selector_params = Keyword.put(opts, :params, http_opts_params)
      http_opts = Keyword.merge([ssl: request_options.ssl_options], opts_with_selector_params)

      K8s.http_provider().request(
        operation.method,
        url,
        http_body,
        http_headers,
        http_opts
      )
    end
  end

  @spec encode(any(), atom()) :: {:ok, binary} | {:error, any}
  def encode(body, http_method) when http_method in [:put, :patch, :post] do
    Jason.encode(body)
  end

  def encode(_, _), do: {:ok, ""}

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
