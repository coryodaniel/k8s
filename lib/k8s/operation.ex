defmodule K8s.Operation do
  @moduledoc "Kubernetes API operations."

  @derive {Jason.Encoder, except: [:path_params]}

  @typedoc """
  * `method` - HTTP Method
  * `verb` - Kubernetes REST API verb (`deletecollection`, `update`, `create`, `watch`, etc)
  * `group_version` - API Group Version, AKA `apiVersion`
  * `resource` - Resource object to use for request, e.g: POSTing a deployment manifest
  * `path_params` - Parameters to interpolate into the Kubernetes REST URL
  * `name` - The name of the kind/resource/subresource being operated on. This is *not* _always_ the same as the `kind` of resource.

  `name` would be `deployments` in the case of a deployment, but may be `deployments/status` or `deployments/scale` for Status and Scale subresources.

  ## `name` and `resource` field examples

  The following example would `update` the *nginx* deployment's `Scale`. Note the `deployments/scale` operation will have a `Scale` *resource*:

  ```elixir
  %K8s.Operation{
    method: :put,
    verb: :update,
    group_version: "v1", # group version of the "Scale" kind
    name: "deployments/scale",
    resource: %{"apiVersion" => "v1", "kind" => "Scale"}, # Resource is of kind "Scale"
    path_params: [name: "nginx", namespace: "default"]
  }
  ```

  The following example would `update` the *nginx* deployment's `Status`. Note the `deployments/status` operation will have a `Deployment` *resource*:

  ```elixir
  %K8s.Operation{
    method: :put,
    verb: :update,
    group_version: "apps/v1", # group version of the "Deployment" kind
    name: "deployments/status",
    resource: %{"apiVersion" => "apps/v1", "kind" => "Deployment"}, # Resource is of kind "Deployment"
    path_params: [name: "nginx", namespace: "default"]
  }
  ```
  """
  @type t :: %__MODULE__{
          method: atom(),
          verb: atom(),
          group_version: binary(),
          name: binary() | atom(),
          resource: map() | nil,
          path_params: keyword(atom())
        }

  @allow_http_body [:put, :patch, :post]
  @verb_map %{
    list_all_namespaces: :get,
    list: :get,
    deletecollection: :delete,
    create: :post,
    update: :put,
    patch: :patch
  }

  defstruct [:method, :verb, :group_version, :name, :resource, :path_params]

  @doc """
  Builds an `Operation` given an verb and a k8s resource.

  ## Examples

      iex> deploy = %{"apiVersion" => "apps/v1", "kind" => "Deployment", "metadata" => %{"namespace" => "default", "name" => "nginx"}}
      ...> K8s.Operation.build(:put, deploy)
      %K8s.Operation{
        method: :put,
        verb: :put,
        resource: %{"apiVersion" => "apps/v1", "kind" => "Deployment", "metadata" => %{"namespace" => "default", "name" => "nginx"}},
        path_params: [namespace: "default", name: "nginx"],
        group_version: "apps/v1",
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
  Builds an `Operation` given an verb and a k8s resource info

  ## Examples
    Building a GET deployment operation:
      iex> K8s.Operation.build(:get, "apps/v1", :deployment, [namespace: "default", name: "nginx"])
      %K8s.Operation{
        method: :get,
        verb: :get,
        resource: nil,
        path_params: [namespace: "default", name: "nginx"],
        group_version: "apps/v1",
        name: :deployment
      }

  Building a GET deployments/status operation:
      iex> K8s.Operation.build(:get, "apps/v1", "deployments/status", [namespace: "default", name: "nginx"])
      %K8s.Operation{
        method: :get,
        verb: :get,
        resource: nil,
        path_params: [namespace: "default", name: "nginx"],
        group_version: "apps/v1",
        name: "deployments/status"
      }
  """
  @spec build(atom, binary, atom | binary, keyword(), map() | nil) :: __MODULE__.t()
  def build(verb, group_version, name, path_params, resource \\ nil) do
    http_method = @verb_map[verb] || verb

    operation_resource =
      case http_method do
        method when method in @allow_http_body -> resource
        _ -> nil
      end

    %__MODULE__{
      method: http_method,
      verb: verb,
      resource: operation_resource,
      group_version: group_version,
      name: name,
      path_params: path_params
    }
  end
end
