defmodule K8s.Client.Runner.Base do
  @moduledoc """
  Base HTTP processor for `K8s.Client`
  """

  @allow_http_body [:put, :patch, :post]
  @type result :: :ok | {:ok, map()} | {:error, binary()}

  alias K8s.Operation
  alias K8s.Conf
  alias K8s.Router

  @doc """
  Runs a `K8s.Operation`.

  ## Examples

  Running a list pods operation:

  ```elixir
  conf = K8s.Conf.from_file "~/.kube/config"
  operation = K8s.Client.list("v1", "Pod", namespace: :all)
  {:ok, %{"items" => pods}} = K8s.Client.run(operation, conf)
  ```

  Running a dry-run of a create deployment operation:

  ```elixir
  conf = K8s.Conf.from_file "~/.kube/config"
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
  :ok = K8s.Client.Runner.Base.run(operation, conf, opts)
  ```
  """
  @spec run(Operation.t(), Conf.t()) :: result
  def run(operation = %{}, config = %{}), do: run(operation, config, [])

  @doc """
  See `run/2`
  """
  @spec run(Operation.t(), Conf.t(), keyword()) :: result
  def run(operation = %{}, config = %{}, opts) when is_list(opts) do
    operation
    |> build_http_req(config, operation.resource, opts)
    |> handle_response
  end

  @doc """
  See `run/2`
  """
  @spec run(Operation.t(), Conf.t(), map(), keyword() | nil) :: result
  def run(operation = %{}, config = %{}, body = %{}, opts \\ []) do
    operation
    |> build_http_req(config, body, opts)
    |> handle_response
  end

  @spec build_http_req(Operation.t(), Conf.t(), map(), keyword()) ::
          {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()}
          | {:error, HTTPoison.Error.t()}
  defp build_http_req(operation, config, body, opts) do
    request_options = Conf.RequestOptions.generate(config)

    # TODO: since router encapsulates config, this should be the URL, and all this
    # config shit at the Base should go away
    path = Router.path_for(operation)

    url = Path.join(config.url, path)

    http_headers = headers(request_options)
    http_opts = Keyword.merge([ssl: request_options.ssl_options], opts)

    case encode(body, operation.method) do
      {:ok, http_body} ->
        HTTPoison.request(operation.method, url, http_body, http_headers, http_opts)

      error ->
        error
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

  defp headers(ro = %Conf.RequestOptions{}) do
    ro.headers ++ [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  end
end
