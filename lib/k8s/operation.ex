defmodule K8s.Operation do
  @moduledoc """
  Encapsulates a k8s swagger operations
  """

  @type t :: %__MODULE__{
          method: atom(),
          verb: atom(),
          group_version: binary(),
          kind: binary() | atom(),
          resource: map(),
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

  defstruct [:method, :verb, :group_version, :kind, :resource, :path_params]

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
        kind: "Deployment"
      }
  """
  @spec build(atom, map) :: __MODULE__.t()
  def build(
        verb,
        resource = %{
          "apiVersion" => v,
          "kind" => k,
          "metadata" => %{"name" => name, "namespace" => ns}
        }
      ) do
    build(verb, v, k, [namespace: ns, name: name], resource)
  end

  def build(
        verb,
        resource = %{"apiVersion" => v, "kind" => k, "metadata" => %{"name" => name}}
      ) do
    build(verb, v, k, [name: name], resource)
  end

  def build(
        verb,
        resource = %{"apiVersion" => v, "kind" => k, "metadata" => %{"namespace" => ns}}
      ) do
    build(verb, v, k, [namespace: ns], resource)
  end

  def build(verb, resource = %{"apiVersion" => v, "kind" => k}) do
    build(verb, v, k, [], resource)
  end

  @doc """
  Builds an `Operation` given an verb and a k8s resource info

  ## Examples

      iex> K8s.Operation.build(:get, "apps/v1", :deployment, [namespace: "default", name: "nginx"])
      %K8s.Operation{
        method: :get,
        verb: :get,
        resource: nil,
        path_params: [namespace: "default", name: "nginx"],
        group_version: "apps/v1",
        kind: :deployment
      }
  """
  @spec build(atom, binary, atom | binary, keyword(), map() | nil) :: __MODULE__.t()
  def build(verb, group_version, kind, path_params, resource \\ nil) do
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
      kind: kind,
      path_params: path_params
    }
  end
end
