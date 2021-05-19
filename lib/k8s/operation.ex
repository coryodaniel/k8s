defmodule K8s.Operation do
  @moduledoc """
  Encapsulates Kubernetes REST API operations.
  """

  alias K8s.Operation
  @derive {Jason.Encoder, except: [:path_params]}

  @allow_http_body [:put, :patch, :post]
  @verb_map %{
    list_all_namespaces: :get,
    list: :get,
    deletecollection: :delete,
    create: :post,
    update: :put,
    patch: :patch
  }

  defstruct method: nil,
            verb: nil,
            api_version: nil,
            name: nil,
            data: nil,
            path_params: [],
            query_params: %{},
            label_selector: nil

  @typedoc "`K8s.Operation` name. May be an atom, string, or tuple of `{resource, subresource}`."
  @type name_t :: binary() | atom() | {binary(), binary()}

  @typedoc """
  * `api_version` - API `groupVersion`, AKA `apiVersion`
  * `name` - The name of the REST operation (Kubernets kind/resource/subresource). This is *not* _always_ the same as the `kind` key in the `data` field. e.g: `deployments` when POSTing, GETting a deployment.
  * `data` - HTTP request body to submit when applicable. (POST, PUT, PATCH, etc)
  * `method` - HTTP Method
  * `verb` - Kubernetes [REST API verb](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#determine-the-request-verb) (`deletecollection`, `update`, `create`, `watch`, etc)
  * `path_params` - Parameters to interpolate into the Kubernetes REST URL
  * `query_params` - Query parameter (`map`). Merged w/ params provided to any `K8s.Client.Runner`. `K8s.Client.Runner` options win.

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
    path_params: [name: "nginx", namespace: "default"]
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
    path_params: [name: "nginx", namespace: "default"]
  }
  ```

  """
  @type t :: %__MODULE__{
          method: atom(),
          verb: atom(),
          api_version: binary(),
          name: name_t(),
          data: map() | nil,
          path_params: keyword(atom()),
          label_selector: K8s.Selector.t() | nil,
          query_params: map()
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
  @spec build(atom, map) :: __MODULE__.t()
  def build(
        verb,
        %{
          "apiVersion" => v,
          "kind" => k,
          "metadata" => %{"name" => name, "namespace" => ns}
        } = resource
      ) do
    build(verb, v, k, [namespace: ns, name: name], resource)
  end

  def build(
        verb,
        %{"apiVersion" => v, "kind" => k, "metadata" => %{"name" => name}} = resource
      ) do
    build(verb, v, k, [name: name], resource)
  end

  def build(
        verb,
        %{"apiVersion" => v, "kind" => k, "metadata" => %{"namespace" => ns}} = resource
      ) do
    build(verb, v, k, [namespace: ns], resource)
  end

  def build(verb, %{"apiVersion" => v, "kind" => k} = resource) do
    build(verb, v, k, [], resource)
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
  @spec build(atom, binary, name_t(), keyword(), map() | nil) :: __MODULE__.t()
  def build(verb, api_version, name_or_kind, path_params, data \\ nil) do
    http_method = @verb_map[verb] || verb

    http_body =
      case http_method do
        method when method in @allow_http_body -> data
        _ -> nil
      end

    %__MODULE__{
      method: http_method,
      verb: verb,
      data: http_body,
      api_version: api_version,
      name: name_or_kind,
      path_params: path_params
    }
  end

  @doc "Converts a `K8s.Operation` into a URL path."
  @spec to_path(Operation.t()) ::
          {:ok, String.t()} | {:error, :missing_required_param, list(atom)}
  def to_path(%Operation{} = operation), do: Operation.Path.build(operation)

  @doc """
  Add a query param to an operation.

  ## Examples

      iex> operation = %K8s.Operation{}
      ...> K8s.Operation.put_query_param(operation, "foo", "bar")
      %K8s.Operation{query_params: %{"foo" => "bar"}}

  """
  @spec put_query_param(Operation.t(), atom(), String.t() | K8s.Selector.t()) :: Operation.t()
  def put_query_param(%Operation{query_params: params} = op, key, value) do
    new_params = Map.put(params, key, value)
    %Operation{op | query_params: new_params}
  end

  @doc """
  Get a query param of an operation

  ## Examples

      iex> operation = %K8s.Operation{query_params: %{foo: "bar"}}
      ...> K8s.Operation.get_query_param(operation, :foo)
      "bar"

  """
  @spec get_query_param(Operation.t(), atom()) :: any()
  def get_query_param(%Operation{query_params: params}, key), do: Map.get(params, key)
end
