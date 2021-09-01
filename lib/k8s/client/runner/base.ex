defmodule K8s.Client.Runner.Base do
  @moduledoc """
  Base HTTP processor for `K8s.Client`.
  """

  @type error_t ::
          {:error, K8s.Middleware.Error.t()}
          | {:error, K8s.Operation.Error.t()}
          | {:error, K8s.Client.APIError.t()}
          | {:error, K8s.Discovery.Error.t()}
          | {:error, atom()}
          | {:error, binary()}
  @type result_t :: {:ok, map() | reference()} | error_t

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
  {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
  operation = K8s.Client.list("v1", "Pod", namespace: :all)
  {:ok, %{"items" => pods}} = K8s.Client.run(conn, operation)
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

  {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
  {:ok, result} = K8s.Client.Runner.Base.run(conn, operation)
  ```
  """
  @spec run(Conn.t(), Operation.t()) :: result_t
  def run(%Conn{} = conn, %Operation{} = operation),
    do: run(conn, operation, [])

  @doc """
  Run an operation and pass `http_opts` to `K8s.Client.HTTPProvider`
  See `run/2`
  """
  @spec run(Conn.t(), Operation.t(), keyword()) :: result_t
  def run(%Conn{} = conn, %Operation{} = operation, http_opts) do
    body = operation.data

    with {:ok, url} <- K8s.Discovery.url_for(conn, operation),
         req <- new_request(conn, url, operation, body, http_opts),
         {:ok, req} <- K8s.Middleware.run(req, conn.middleware.request) do
      conn.http_provider.request(req.method, req.url, req.body, req.headers, req.opts)
    end
  end

  @spec new_request(Conn.t(), String.t(), Operation.t(), body_t, Keyword.t()) ::
          Request.t()
  defp new_request(%Conn{} = conn, url, %Operation{} = operation, body, http_opts) do
    req = %Request{conn: conn, method: operation.method, body: body, url: url}

    headers =
      case operation.verb do
        :patch -> ["Content-Type": "application/merge-patch+json"]
        :apply -> ["Content-Type": "application/apply-patch+yaml"]
        _ -> ["Content-Type": "application/json"]
      end

    operation_query_params = build_query_params(operation)
    http_opts_params = Keyword.get(http_opts, :params, [])
    merged_params = Keyword.merge(operation_query_params, http_opts_params)
    http_opts_w_merged_params = Keyword.put(http_opts, :params, merged_params)
    updated_http_opts = Keyword.merge(req.opts, http_opts_w_merged_params)

    %Request{req | opts: updated_http_opts, headers: headers}
  end

  @spec build_query_params(Operation.t()) :: keyword()
  defp build_query_params(%Operation{} = operation) do
    label_selector = Operation.get_label_selector(operation)
    field_selector = Operation.get_field_selector(operation)

    Keyword.merge(operation.query_params,
      labelSelector: K8s.Selector.labels_to_s(label_selector),
      fieldSelector: K8s.Selector.fields_to_s(field_selector)
    )
  end
end
