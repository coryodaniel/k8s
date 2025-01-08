defmodule K8s.Client.Runner.Base do
  @moduledoc """
  Base HTTP processor for `K8s.Client`.
  """

  @typedoc "Acceptable HTTP body types"
  @type body_t :: list(map()) | map() | binary() | nil

  @type error_t ::
          {:error, K8s.Middleware.Error.t()}
          | {:error, K8s.Operation.Error.t()}
          | {:error, K8s.Client.APIError.t()}
          | {:error, K8s.Discovery.Error.t()}
          | {:error, atom()}
          | {:error, binary()}
  @type result_t :: {:ok, map() | reference() | body_t} | error_t

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
  @spec run(Operation.t()) :: result_t
  def run(%Operation{conn: %Conn{} = conn} = operation),
    do: run(conn, operation, [])

  @spec run(Conn.t(), Operation.t()) :: result_t
  def run(%Conn{} = conn, %Operation{} = operation),
    do: run(conn, operation, [])

  @spec run(Operation.t(), keyword()) :: result_t
  def run(%Operation{conn: %Conn{} = conn} = operation, http_opts),
    do: run(conn, operation, http_opts)

  @doc """
  Run a connect operation and pass `websocket_driver_opts` to `K8s.Client.WebSocketProvider`
  See `run/3`
  """
  @spec run(Conn.t(), Operation.t(), keyword()) :: result_t
  def run(_conn, %Operation{verb: :watch}, _) do
    msg = "Watch operations have to be streamed. Use K8s.Client.stream/N"

    {:error, %K8s.Operation.Error{message: msg}}
  end

  # Run an operation and pass `http_opts` to `K8s.Client.HTTPProvider`
  def run(%Conn{} = conn, %Operation{verb: :connect} = operation, http_opts) do
    with {:ok, url} <- K8s.Discovery.url_for(conn, operation),
         req <- new_request(conn, url, operation, operation.data, http_opts),
         {:ok, req} <- K8s.Middleware.run(req, conn.middleware.request) do
      conn.http_provider.websocket_request(
        req.uri,
        Keyword.merge(req.headers, Accept: "*/*"),
        req.opts
      )
    end
  end

  # Run an operation and pass `http_opts` to `K8s.Client.HTTPProvider`
  def run(%Conn{} = conn, %Operation{} = operation, http_opts) do
    with {:ok, url} <- K8s.Discovery.url_for(conn, operation),
         req <- new_request(conn, url, operation, operation.data, http_opts),
         {:ok, req} <- K8s.Middleware.run(req, conn.middleware.request) do
      conn.http_provider.request(req.method, req.uri, req.body, req.headers, req.opts)
    end
  end

  @doc """
  Runs a `K8s.Operation` and streams the response.
  """
  @spec stream(Conn.t(), Operation.t(), keyword()) :: K8s.Client.Provider.stream_response_t()
  def stream(%Conn{} = conn, %Operation{verb: :connect} = operation, http_opts) do
    with {:ok, url} <- K8s.Discovery.url_for(conn, operation),
         req <- new_request(conn, url, operation, operation.data, http_opts),
         {:ok, req} <- K8s.Middleware.run(req, conn.middleware.request) do
      conn.http_provider.websocket_stream(
        req.uri,
        Keyword.merge(req.headers, Accept: "*/*"),
        req.opts
      )
    end
  end

  def stream(%Conn{} = conn, %Operation{} = operation, http_opts) do
    with {:ok, url} <- K8s.Discovery.url_for(conn, operation),
         req <- new_request(conn, url, operation, operation.data, http_opts),
         {:ok, req} <- K8s.Middleware.run(req, conn.middleware.request) do
      conn.http_provider.stream(
        req.method,
        req.uri,
        req.body,
        req.headers,
        req.opts
      )
    end
  end

  @doc """
  Runs a `K8s.Operation` and streams the response.
  """
  @spec stream_to(Conn.t(), Operation.t(), keyword(), pid()) ::
          K8s.Client.Provider.stream_to_response_t()
  def stream_to(%Conn{} = conn, %Operation{verb: :connect} = operation, http_opts, stream_to) do
    with {:ok, url} <- K8s.Discovery.url_for(conn, operation),
         req <- new_request(conn, url, operation, operation.data, http_opts),
         {:ok, req} <- K8s.Middleware.run(req, conn.middleware.request) do
      conn.http_provider.websocket_stream_to(
        req.uri,
        Keyword.merge(req.headers, Accept: "*/*"),
        req.opts,
        stream_to
      )
    end
  end

  def stream_to(%Conn{} = conn, %Operation{} = operation, http_opts, stream_to) do
    with {:ok, url} <- K8s.Discovery.url_for(conn, operation),
         req <- new_request(conn, url, operation, operation.data, http_opts),
         {:ok, req} <- K8s.Middleware.run(req, conn.middleware.request) do
      conn.http_provider.stream_to(
        req.method,
        req.uri,
        req.body,
        req.headers,
        req.opts,
        stream_to
      )
    end
  end

  @spec new_request(
          Conn.t(),
          binary(),
          Operation.t(),
          String.t() | nil,
          keyword()
        ) :: Request.t()
  defp new_request(%Conn{} = conn, url, %Operation{} = operation, body, http_opts) do
    req = %Request{conn: conn, method: operation.method, body: body}

    headers = operation.header_params
    operation_query_params = build_query_params(operation)
    http_opts_params = Keyword.get(http_opts, :params, [])
    merged_params = Keyword.merge(operation_query_params, http_opts_params)

    uri = url |> URI.parse() |> URI.append_query(URI.encode_query(merged_params))

    %Request{req | opts: http_opts, headers: headers, uri: uri}
  end

  @spec build_query_params(Operation.t()) :: String.t() | keyword()
  defp build_query_params(operation) do
    {commands, query_params} = Keyword.pop_values(operation.query_params, :command)

    commands =
      commands
      |> List.flatten()
      |> Enum.map(&{:command, &1})

    selector = Operation.get_selector(operation)

    selectors =
      [
        labelSelector: K8s.Selector.labels_to_s(selector),
        fieldSelector: K8s.Selector.fields_to_s(selector)
      ]
      |> Keyword.reject(&(elem(&1, 1) == ""))

    query_params
    |> Keyword.delete(:labelSelector)
    |> Keyword.merge(selectors)
    |> Keyword.merge(commands)
  end
end
