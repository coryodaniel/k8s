defmodule K8s.Router do
  @moduledoc """
  Encapsulates a route map built from kubernetes' swagger operations.
  """

  alias K8s.Swagger
  alias K8s.Operation

  @doc """
  Creates a route map from a swagger spec.

  ## Examples

      iex> K8s.Router.generate_routes("./test/support/swagger/simple.json")
      %{
        "deletecollection/apps/v1/deployment/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments",
        "list/apps/v1/deployment/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments",
        "post/apps/v1/deployment/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments",
        "delete/apps/v1/deployment/name/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments/{name}",
        "get/apps/v1/deployment/name/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments/{name}",
        "patch/apps/v1/deployment/name/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments/{name}",
        "put/apps/v1/deployment/name/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments/{name}"
      }
  """
  @spec generate_routes(binary | map) :: map
  def generate_routes(spec_path_or_spec_map) do
    spec_path_or_spec_map
    |> Swagger.build()
    |> Map.values()
    |> Enum.reduce(%{}, fn metadata, agg ->
      path_with_args = metadata["path"]

      action_name = Swagger.gen_action_name(metadata)
      api_version = metadata["api_version"]
      kind = metadata["kind"]
      arg_names = Swagger.find_params(path_with_args)

      key = Operation.id(action_name, api_version, kind, arg_names)
      Map.put(agg, key, path_with_args)
    end)
  end

  @doc """
  Replaces path variables with options.

  ## Examples

      iex> K8s.Router.replace_path_vars("/foo/{name}", name: "bar")
      "/foo/bar"

  """
  @spec replace_path_vars(binary(), keyword(atom())) :: binary()
  def replace_path_vars(path_template, opts) do
    Regex.replace(~r/\{(\w+?)\}/, path_template, fn _, var ->
      opts[String.to_existing_atom(var)]
    end)
  end
end
