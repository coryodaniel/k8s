defmodule K8s.Client.Runner.Base do
  @moduledoc """
  Base HTTP processor for `K8s.Client`
  """

  @type result :: {:ok, map()} | {:error, binary() | atom} | {:error, atom, binary}

  alias K8s.Cluster
  alias K8s.Conf.RequestOptions
  alias K8s.Operation

  @doc """
  Runs a `K8s.Operation`.

  ## Examples

  *Note:* Examples assume a cluster was registered named "test-cluster", see `K8s.Cluster.register/2`.

  Running a list pods operation:

  ```elixir
  operation = K8s.Client.list("v1", "Pod", namespace: :all)
  {:ok, %{"items" => pods}} = K8s.Client.run(operation, "test-cluster")
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
  :ok = K8s.Client.Runner.Base.run(operation, "test-cluster", opts)
  ```
  """
  @spec run(Operation.t(), binary) :: result
  def run(operation = %Operation{}, cluster_name \\ :default),
    do: run(operation, cluster_name, [])

  @doc """
  See `run/2`
  """
  @spec run(Operation.t(), binary, keyword()) :: result
  def run(operation = %Operation{}, cluster_name, opts) when is_list(opts) do
    operation
    |> build_http_req(cluster_name, operation.resource, opts)
    |> K8s.http_provider().handle_response
  end

  @doc """
  See `run/2`
  """
  @spec run(Operation.t(), binary, map(), keyword() | nil) :: result
  def run(operation = %Operation{}, cluster_name, body = %{}, opts \\ []) do
    operation
    |> build_http_req(cluster_name, body, opts)
    |> K8s.http_provider().handle_response
  end

  @spec encode(any(), atom()) :: {:ok, binary} | {:error, binary}
  def encode(body, _) when not is_map(body), do: {:ok, ""}

  def encode(body = %{}, http_method) when http_method in [:put, :patch, :post] do
    Jason.encode(body)
  end

  @spec build_http_req(Operation.t(), binary, map(), keyword()) ::
          {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()}
          | {:error, HTTPoison.Error.t()}
  defp build_http_req(operation = %Operation{}, cluster_name, body, opts) do
    case Cluster.url_for(operation, cluster_name) do
      {:error, type, details} ->
        {:error, type, details}

      nil ->
        {:error, :path_not_found}

      url ->
        conf = Cluster.conf(cluster_name)
        request_options = RequestOptions.generate(conf)
        http_headers = K8s.http_provider().headers(request_options)
        http_opts = Keyword.merge([ssl: request_options.ssl_options], opts)

        case encode(body, operation.method) do
          {:ok, http_body} ->
            K8s.http_provider().request(operation.method, url, http_body, http_headers, http_opts)

          error ->
            error
        end
    end
  end
end
