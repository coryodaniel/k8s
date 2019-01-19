defmodule K8s.Operation do
  @moduledoc """
  Encapsulates a k8s swagger operations
  """

  @type t :: %__MODULE__{
          method: atom(),
          resource: map(),
          id: binary(),
          path_params: keyword(atom())
        }

  @allow_http_body [:put, :patch, :post]

  @action_map %{
    list_all_namespaces: :get,
    list: :get,
    patch_status: :patch,
    get_status: :get,
    delete_collection: :delete,
    get_log: :get,
    put_status: :put
  }

  defstruct [:method, :id, :resource, :path_params]

  @doc """
  Builds an `Operation` given an action and a k8s resource.

  ## Examples

      iex> deploy = %{"apiVersion" => "apps/v1", "kind" => "Deployment", "metadata" => %{"namespace" => "default", "name" => "nginx"}}
      ...> K8s.Operation.build(:put, deploy)
      %K8s.Operation{
        method: :put,
        resource: %{"apiVersion" => "apps/v1", "kind" => "Deployment", "metadata" => %{"namespace" => "default", "name" => "nginx"}},
        id: "put/apps/v1/deployment/name/namespace",
        path_params: [namespace: "default", name: "nginx"]
      }
  """
  @spec build(atom, map) :: __MODULE__.t()
  def build(
        action,
        resource = %{
          "apiVersion" => v,
          "kind" => k,
          "metadata" => %{"name" => name, "namespace" => ns}
        }
      ) do
    build(action, v, k, [namespace: ns, name: name], resource)
  end

  def build(
        action,
        resource = %{"apiVersion" => v, "kind" => k, "metadata" => %{"name" => name}}
      ) do
    build(action, v, k, [name: name], resource)
  end

  def build(
        action,
        resource = %{"apiVersion" => v, "kind" => k, "metadata" => %{"namespace" => ns}}
      ) do
    build(action, v, k, [namespace: ns], resource)
  end

  def build(action, resource = %{"apiVersion" => v, "kind" => k}) do
    build(action, v, k, [], resource)
  end

  @doc """
  Builds an `Operation` given an action and a k8s resource info

  ## Examples

      iex> K8s.Operation.build(:get, "apps/v1", :deployment, [namespace: "default", name: "nginx"])
      %K8s.Operation{
        method: :get,
        resource: nil,
        id: "get/apps/v1/deployment/name/namespace",
        path_params: [namespace: "default", name: "nginx"]
      }
  """
  @spec build(atom, binary, atom | binary, keyword(atom), map()) :: __MODULE__.t()
  def build(action, api_version, kind, path_params, resource \\ nil) do
    http_method = @action_map[action] || action

    operation_resource =
      case http_method do
        method when method in @allow_http_body -> resource
        _ -> nil
      end

    %__MODULE__{
      method: http_method,
      resource: operation_resource,
      id: id(action, api_version, kind, Keyword.keys(path_params)),
      path_params: path_params
    }
  end

  @doc """
  Generates an `Operation` ID given an action and a k8s resource info

  Sorts the args because the interpolation doesn't care and it makes finding the key much easier.

  ## Examples

      iex> K8s.Operation.id(:get, "v1", "Pod", [:name, :namespace])
      "get/v1/pod/name/namespace"

      iex> K8s.Operation.id(:get, "v1", :Pod, [:name, :namespace])
      "get/v1/pod/name/namespace"

      iex> K8s.Operation.id(:get, "v1", :pod, [:name, :namespace])
      "get/v1/pod/name/namespace"

  """
  @spec id(binary, binary, binary, list(atom)) :: binary
  def id(action_name, api_version, kind, arg_names) do
    formatted_kind = String.downcase("#{kind}")
    key_list = [action_name, api_version, formatted_kind] ++ Enum.sort(arg_names)
    Enum.join(key_list, "/")
  end
end
