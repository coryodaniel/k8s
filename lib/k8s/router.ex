defmodule K8s.Router do
  @moduledoc """
  Encapsulates a route map built from kubernetes' swagger operations.
  """

  alias K8s.Swagger
  alias K8s.Operation

  @table_prefix :k8s_router

  @doc """
  Start a new router. Returns the name of the `Router`. The default name is `:default`

  ## Examples

  Starting a K8s 1.13 router:

  ```elixir
  router_name = K8s.Router.start("priv/swagger/1.13.json")
  ```

  Starting a named K8s 1.10 router:

  ```elixir
  router_name = K8s.Router.start("priv/swagger/1.10.json", :legacy)
  ```
  """
  @spec start(binary | map, atom | nil) :: atom
  def start(spec_path_or_spec_map, name \\ :default) do
    table_name = create_table(name)

    spec_path_or_spec_map
    |> to_metadata
    |> Enum.each(fn {key, path} ->
      :ets.insert(table_name, {key, path})
    end)

    name
  end

  @doc false
  @spec lookup(binary, binary | atom) :: binary | nil
  def lookup(key, name) do
    case :ets.lookup(name, key) do
      [] -> nil
      [{_, path}] -> path
    end
  end

  @doc """
  Creates a route map from a swagger spec.

  ## Examples

      iex> K8s.Router.to_metadata("priv/custom/simple.json")
      %{
        "delete_collection/apps/v1/deployment/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments",
        "list/apps/v1/deployment/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments",
        "post/apps/v1/deployment/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments",
        "delete/apps/v1/deployment/name/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments/{name}",
        "get/apps/v1/deployment/name/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments/{name}",
        "patch/apps/v1/deployment/name/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments/{name}",
        "put/apps/v1/deployment/name/namespace" => "/apis/apps/v1/namespaces/{namespace}/deployments/{name}"
      }
  """
  @spec to_metadata(binary | map) :: map
  def to_metadata(spec_path_or_spec_map) do
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

  # Create a namespaced ets table name
  @spec to_table_name(atom) :: atom
  defp to_table_name(name), do: String.to_atom("#{@table_prefix}_#{name}")

  # Create an ets table if it doesn't exist
  @spec create_table(atom) :: atom | {:error, :router_exists}
  defp create_table(name) do
    table_name = to_table_name(name)

    case :ets.info(table_name) do
      :undefined -> :ets.new(table_name, [:set, :protected, :named_table])
      _ -> {:error, :router_exists}
    end
  end

  @doc """
  Find the path for a `K8s.Operation`

  ## Examples

      iex> op = K8s.Operation.build(:get, "apps/v1", :deployment, [namespace: "default", name: "nginx"])
      ...> K8s.Router.path_for(op)
      "/apis/apps/v1/namespaces/default/deployments/nginx"
  """
  @spec path_for(Operation.t(), atom) :: binary() | {:error, binary()}
  def path_for(operation, router_name \\ :default) do
    path = lookup(operation.id, to_table_name(router_name))

    case path do
      nil -> {:error, "Unsupported operation: #{operation.id}"}
      template -> replace_path_vars(template, operation.path_params)
    end
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
