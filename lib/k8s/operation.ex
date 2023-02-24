defmodule K8s.Operation do
  @moduledoc "Encapsulates Kubernetes REST API operations."

  alias K8s.{Operation, Selector}
  alias K8s.Operation.Error
  @derive {Jason.Encoder, except: [:path_params, :header_params]}

  @typedoc "Acceptable patch types"
  @type patch_type :: :strategic_merge | :merge | :json_merge | :apply

  @allow_http_body [:put, :patch, :post]
  @selector :labelSelector
  @verb_map %{
    list_all_namespaces: :get,
    watch_all_namespaces: :get,
    list: :get,
    watch: :get,
    deletecollection: :delete,
    create: :post,
    connect: :post,
    update: :put,
    patch: :patch,
    apply: :patch
  }

  @patch_type_header_map %{
    merge: ["Content-Type": "application/merge-patch+json"],
    strategic_merge: ["Content-Type": "application/strategic-merge-patch+json"],
    json_merge: ["Content-Type": "application/json-patch+json"],
    apply: ["Content-Type": "application/apply-patch+yaml"]
  }

  defstruct method: nil,
            verb: nil,
            api_version: nil,
            name: nil,
            data: nil,
            conn: nil,
            path_params: [],
            query_params: [],
            header_params: []

  @typedoc "`K8s.Operation` name. May be an atom, string, or tuple of `{resource, subresource}`."
  @type name_t :: binary() | atom() | {binary(), binary()}

  @typedoc """
  * `api_version` - API `groupVersion`, AKA `apiVersion`
  * `name` - The name of the REST operation (Kubernets kind/resource/subresource). This is *not* _always_ the same as the `kind` key in the `data` field. e.g: `deployments` when POSTing, GETting a deployment.
  * `data` - HTTP request body to submit when applicable. (POST, PUT, PATCH, etc)
  * `method` - HTTP Method
  * `verb` - Kubernetes [REST API verb](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#determine-the-request-verb) (`deletecollection`, `update`, `create`, `watch`, etc)
  * `path_params` - Parameters to interpolate into the Kubernetes REST URL
  * `query_params` - Query parameters. Merged w/ params provided to any `K8s.Client.Runner`. `K8s.Client.Runner` options win.
  * `header_params` - Header parameters. Merged w/ default headers depending on the operation.

  `name` would be `deployments` in the case of a deployment, but may be `deployments/status` or `deployments/scale` for Status and Scale subresources.

  ## `name` and `data` field examples

  The following example would `update` the *nginx* deployment's `Scale`. Note the `deployments/scale` operation will have a `Scale` *data* payload:

  ```elixir
  %K8s.Operation{
    method: :put,
    verb: :update,
    api_version: "v1", # api version of the "Scale" kind
    name: "deployments/scale",
    data: %{"apiVersion" => "v1", "kind" => "Scale"}, # `data` is of kind "Scale"
    path_params: [name: "nginx", namespace: "default"],
    header_params: ["Custom": "Header"]
  }
  ```

  The following example would `update` the *nginx* deployment's `Status`. Note the `deployments/status` operation will have a `Deployment` *data* payload:

  ```elixir
  %K8s.Operation{
    method: :put,
    verb: :update,
    api_version: "apps/v1", # api version of the "Deployment" kind
    name: "deployments/status",
    data: %{"apiVersion" => "apps/v1", "kind" => "Deployment"}, # `data` is of kind "Deployment"
    path_params: [name: "nginx", namespace: "default"],
    header_params: ["Custom": "Header"]
  }
  ```
  """
  @type t :: %__MODULE__{
          method: atom(),
          verb: atom(),
          api_version: binary(),
          name: name_t(),
          data: map() | nil,
          conn: K8s.Conn.t() | nil,
          path_params: keyword(),
          query_params: keyword(),
          header_params: keyword()
        }

  @doc """
  Builds an `Operation` given a verb and a k8s resource.

  ## Examples

      iex> deploy = %{"apiVersion" => "apps/v1", "kind" => "Deployment", "metadata" => %{"namespace" => "default", "name" => "nginx"}}
      ...> K8s.Operation.build(:update, deploy)
      %K8s.Operation{
        method: :put,
        verb: :update,
        data: %{"apiVersion" => "apps/v1", "kind" => "Deployment", "metadata" => %{"namespace" => "default", "name" => "nginx"}},
        path_params: [namespace: "default", name: "nginx"],
        api_version: "apps/v1",
        name: "Deployment"
      }
  """
  @spec build(atom(), map(), keyword()) :: __MODULE__.t()
  def build(verb, resource, opts \\ [])

  def build(
        verb,
        %{
          "apiVersion" => v,
          "kind" => k,
          "metadata" => %{"name" => name, "namespace" => ns}
        } = resource,
        opts
      ) do
    build(verb, v, k, [namespace: ns, name: name], resource, opts)
  end

  def build(
        verb,
        %{"apiVersion" => v, "kind" => k, "metadata" => %{"name" => name}} = resource,
        opts
      ) do
    build(verb, v, k, [name: name], resource, opts)
  end

  def build(
        verb,
        %{"apiVersion" => v, "kind" => k, "metadata" => %{"namespace" => ns}} = resource,
        opts
      ) do
    build(verb, v, k, [namespace: ns], resource, opts)
  end

  def build(verb, %{"apiVersion" => v, "kind" => k} = resource, opts) do
    build(verb, v, k, [], resource, opts)
  end

  @doc """
  Builds an `Operation` given an verb and a k8s resource info.

  *Note:* The `name` here may be a `Kind` and not a REST resource name in the event that the operation was built using a map.
  Use `K8s.Discovery.ResourceFinder.resource_name_for_kind/3` to get the correct REST resource name, given a `kind`.

  ## Examples
    Building a GET deployment operation:
      iex> K8s.Operation.build(:get, "apps/v1", :deployment, [namespace: "default", name: "nginx"])
      %K8s.Operation{
        method: :get,
        verb: :get,
        data: nil,
        path_params: [namespace: "default", name: "nginx"],
        api_version: "apps/v1",
        name: :deployment
      }

  Building a GET deployments/status operation:
      iex> K8s.Operation.build(:get, "apps/v1", "deployments/status", [namespace: "default", name: "nginx"])
      %K8s.Operation{
        method: :get,
        verb: :get,
        data: nil,
        path_params: [namespace: "default", name: "nginx"],
        api_version: "apps/v1",
        name: "deployments/status"
      }
  """
  @spec build(atom, binary, name_t(), keyword(), map() | nil, keyword()) :: __MODULE__.t()
  def build(verb, api_version, name_or_kind, path_params, data \\ nil, opts \\ []) do
    http_method = @verb_map[verb] || verb

    http_body =
      case http_method do
        method when method in @allow_http_body -> data
        _ -> nil
      end

    query_params =
      case verb do
        :apply ->
          [
            fieldManager: Keyword.get(opts, :field_manager, "elixir"),
            force: Keyword.get(opts, :force, true)
          ]

        :connect ->
          [stdin: true, stdout: true, stderr: true, tty: false]
          |> Keyword.merge(
            Keyword.take(opts, [:stdin, :stdout, :stderr, :tty, :command, :container])
          )

        _ ->
          []
      end

    header_params =
      case {verb, Keyword.get(opts, :patch_type, :not_set)} do
        {:patch, merge_patch_types} when merge_patch_types in [:merge, :not_set] ->
          @patch_type_header_map[:merge]
        {:patch, :strategic_merge} ->
          @patch_type_header_map[:strategic_merge]
        {:patch, :json_merge} ->
          @patch_type_header_map[:json_merge]
        {:apply, apply_patch_types} when apply_patch_types in [:apply, :not_set] ->
          @patch_type_header_map[:apply]
        _ -> ["Content-Type": "application/json"]
      end
      |> Keyword.merge(Keyword.get(opts, :header_params, []))

    %__MODULE__{
      method: http_method,
      verb: verb,
      data: http_body,
      api_version: api_version,
      name: name_or_kind,
      path_params: path_params,
      query_params: query_params,
      header_params: header_params
    }
  end

  @doc "Converts a `K8s.Operation` into a URL path."
  @spec to_path(t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def to_path(%Operation{} = operation), do: Operation.Path.build(operation)

  @deprecated "Use put_selector/2"
  @spec put_label_selector(t(), Selector.t()) :: t()
  defdelegate put_label_selector(op, selector), to: __MODULE__, as: :put_selector

  @doc """
  Puts a `K8s.Selector` on the operation.

  ## Examples
      iex> operation = %K8s.Operation{}
      ...> selector = K8s.Selector.label({"component", "redis"})
      ...> K8s.Operation.put_selector(operation, selector)
      %K8s.Operation{
        query_params: [
          labelSelector: %K8s.Selector{
            match_expressions: [],
            match_labels: %{"component" => {"=", "redis"}}
          }
        ]
      }
  """
  @spec put_selector(t(), Selector.t()) :: t()
  def put_selector(%Operation{} = op, %Selector{} = selector),
    do: put_query_param(op, @selector, selector)

  @deprecated "Use get_selector/1"
  @spec get_label_selector(t()) :: K8s.Selector.t()
  defdelegate get_label_selector(operation), to: __MODULE__, as: :get_selector

  @doc """
  Gets a `K8s.Selector` on the operation.

  ## Examples
      iex> operation = %K8s.Operation{query_params: [labelSelector: K8s.Selector.label({"component", "redis"})]}
      ...> K8s.Operation.get_selector(operation)
      %K8s.Selector{
        match_expressions: [],
        match_labels: %{"component" => {"=", "redis"}}
      }
  """
  @spec get_selector(t()) :: K8s.Selector.t()
  def get_selector(%Operation{query_params: params}),
    do: Keyword.get(params, @selector, %K8s.Selector{})

  @doc """
  Add a query param to an operation

  ## Examples
    Using a `keyword` list of params:
      iex> operation = %K8s.Operation{}
      ...> K8s.Operation.put_query_param(operation, :foo, "bar")
      %K8s.Operation{query_params: [foo: "bar"]}
  """
  @spec put_query_param(t(), any(), String.t() | K8s.Selector.t()) :: t()
  def put_query_param(%Operation{query_params: params} = op, key, value) when is_list(params) do
    new_params = Keyword.put(params, key, value)
    %Operation{op | query_params: new_params}
  end

  # covers when query_params are a keyword list for operations like for Pod Connect
  def put_query_param(%Operation{query_params: params} = op, opts)
      when is_list(opts) and is_list(params) do
    new_params = params ++ opts
    %Operation{op | query_params: new_params}
  end

  @spec put_query_param(t(), list() | K8s.Selector.t()) :: t()
  def put_query_param(%Operation{query_params: _params} = op, opts) when is_list(opts) do
    %Operation{op | query_params: opts}
  end

  @doc """
  Get a query param of an operation

  ## Examples
    Using a `keyword` list of params:
      iex> operation = %K8s.Operation{query_params: [foo: "bar"]}
      ...> K8s.Operation.get_query_param(operation, :foo)
      "bar"
  """
  @spec get_query_param(t(), atom()) :: any()
  def get_query_param(%Operation{query_params: params}, key), do: Keyword.get(params, key)

  @doc """
  Set the connection object on the operation

  ## Examples
      iex> operation = %K8s.Operation{query_params: [foo: "bar"]}
      ...> conn = %K8s.Conn{}
      ...> operation = K8s.Operation.put_conn(operation, conn)
      ...> match?(%K8s.Operation{conn: %K8s.Conn{}}, operation)
      true
  """
  @spec put_conn(t(), K8s.Conn.t()) :: t()
  def put_conn(operation, conn), do: struct!(operation, conn: conn)

  @doc """
  Adds a header param to an operation

  ## Examples
    Using a `keyword` list of params:
      iex> operation = %K8s.Operation{}
      ...> K8s.Operation.put_header_param(operation, :"Custom-Header", "SomeValue")
      %K8s.Operation{header_params: ["Custom-Header": "SomeValue"]}
  """
  @spec put_header_param(t(), String.t() | atom(), String.t()) :: t()
  def put_header_param(%Operation{header_params: params} = op, key, value) when is_list(params) do
    new_params = Keyword.put(params, key, value)
    %Operation{op | header_params: new_params}
  end
end
