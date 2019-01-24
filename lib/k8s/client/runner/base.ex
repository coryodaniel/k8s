defmodule K8s.Client.Runner.Base do
  @moduledoc """
  Base HTTP processor for `K8s.Client`
  """

  @allow_http_body [:put, :patch, :post]
  @type result :: :ok | {:ok, map()} | {:error, binary()}

  alias K8s.Cluster
  alias K8s.Conf.RequestOptions
  alias K8s.Operation

  @doc """
  Runs a `K8s.Operation`.

  ## Examples

  *Note:* Examples assume a cluster was registered named "test-cluster", see `K8s.Cluster.register/3`.

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
  def run(operation = %{}, cluster_name), do: run(operation, cluster_name, [])

  @doc """
  See `run/2`
  """
  @spec run(Operation.t(), binary, keyword()) :: result
  def run(operation = %{}, cluster_name, opts) when is_list(opts) do
    operation
    |> build_http_req(cluster_name, operation.resource, opts)
    |> handle_response
  end

  @doc """
  See `run/2`
  """
  @spec run(Operation.t(), binary, map(), keyword() | nil) :: result
  def run(operation = %{}, cluster_name, body = %{}, opts \\ []) do
    operation
    |> build_http_req(cluster_name, body, opts)
    |> handle_response
  end

  @spec build_http_req(Operation.t(), binary, map(), keyword()) ::
          {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()}
          | {:error, HTTPoison.Error.t()}
  defp build_http_req(operation, cluster_name, body, opts) do
    case Cluster.url_for(operation, cluster_name) do
      nil ->
        {:error, :path_not_found}

      url ->
        conf = Cluster.conf(cluster_name)
        request_options = RequestOptions.generate(conf)
        http_headers = headers(request_options)
        http_opts = Keyword.merge([ssl: request_options.ssl_options], opts)

        case encode(body, operation.method) do
          {:ok, http_body} ->
            HTTPoison.request(operation.method, url, http_body, http_headers, http_opts)

          error ->
            error
        end
    end
  end

  @spec encode(any(), atom()) :: {:ok, binary} | {:error, binary}
  defp encode(body, _) when not is_map(body), do: {:ok, ""}

  defp encode(body = %{}, http_method) when http_method in @allow_http_body do
    Jason.encode(body)
  end

  @spec decode(binary()) :: list | map | nil
  defp decode(body) do
    case Jason.decode(body) do
      {:ok, data} -> data
      {:error, _} -> nil
    end
  end

  @spec handle_response(
          {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()}
          | {:error, HTTPoison.Error.t()}
        ) :: {:ok, map()} | {:error, binary()}
  defp handle_response(resp) do
    case resp do
      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 200..299 ->
        {:ok, decode(body)}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, :unauthorized}

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 400..499 ->
        {:error, "HTTP Error: #{code}; #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP Client Error: #{reason}"}
    end
  end

  defp headers(ro = %RequestOptions{}) do
    ro.headers ++ [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  end
end
