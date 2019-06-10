defmodule K8s.Client.Runner.Watch do
  @moduledoc """
  `K8s.Client` runner that will watch a resource or resources and stream results back to a process.
  """

  @resource_version_json_path ~w(metadata resourceVersion)

  alias K8s.Client.Runner.Base
  alias K8s.Operation

  @doc """
  Watch a resource or list of resources. Provide the `stream_to` option or results will be stream to `self()`.

  Note: Current resource version will be looked up automatically.

  ## Examples

  ```elixir
  operation = K8s.Client.list("v1", "Namespace")
  {:ok, reference} = Watch.run(operation, :test, stream_to: self())
  ```

  ```elixir
  operation = K8s.Client.get("v1", "Namespace", [name: "test"])
  {:ok, reference} = Watch.run(operation, :test, stream_to: self())
  ```
  """
  @spec run(Operation.t(), atom, keyword(atom)) :: Base.result_t()
  def run(operation = %Operation{method: :get}, cluster_name, opts) do
    case get_resource_version(operation, cluster_name) do
      {:ok, rv} -> run(operation, cluster_name, rv, opts)
      error -> error
    end
  end

  def run(op, _, _),
    do: {:error, "Only HTTP GET operations (list, get) are supported. #{inspect(op)}"}

  @doc """
  Watch a resource or list of resources from a specific resource version. Provide the `stream_to` option or results will be stream to `self()`.

  ## Examples

  ```elixir
  operation = K8s.Client.list("v1", "Namespace")
  resource_version = 3003
  {:ok, reference} = Watch.run(operation, :test, resource_version, stream_to: self())
  ```

  ```elixir
  operation = K8s.Client.get("v1", "Namespace", [name: "test"])
  resource_version = 3003
  {:ok, reference} = Watch.run(operation, :test, resource_version, stream_to: self())
  ```
  """
  @spec run(Operation.t(), atom, binary, keyword(atom)) :: Base.result_t()
  def run(operation = %Operation{method: :get, verb: verb}, cluster_name, rv, opts)
      when verb in [:list, :list_all_namespaces] do
    opts_w_watch_params = add_watch_params_to_opts(opts, rv)
    Base.run(operation, cluster_name, opts_w_watch_params)
  end

  def run(operation = %Operation{method: :get, verb: :get}, cluster_name, rv, opts) do
    {list_op, field_selector_param} = get_to_list(operation)

    params = Map.merge(opts[:params] || %{}, field_selector_param)
    opts = Keyword.put(opts, :params, params)
    run(list_op, cluster_name, rv, opts)
  end

  def run(op, _, _, _),
    do: {:error, "Only HTTP GET operations (list, get) are supported. #{inspect(op)}"}

  @spec get_resource_version(Operation.t(), atom) :: {:ok, binary} | {:error, binary}
  defp get_resource_version(operation = %Operation{}, cluster_name) do
    case Base.run(operation, cluster_name) do
      {:ok, payload} ->
        rv = parse_resource_version(payload)
        {:ok, rv}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec add_watch_params_to_opts(keyword, binary) :: keyword
  defp add_watch_params_to_opts(opts, rv) do
    params = Map.merge(opts[:params] || %{}, %{"resourceVersion" => rv, "watch" => true})
    Keyword.put(opts, :params, params)
  end

  @spec parse_resource_version(any) :: binary
  defp parse_resource_version(payload = %{}),
    do: get_in(payload, @resource_version_json_path) || "0"

  defp parse_resource_version(_), do: "0"

  defp get_to_list(get_op) do
    list_op = %{get_op | verb: :list, path_params: []}
    name = get_op.path_params[:name]
    params = %{"fieldSelector" => "metadata.name%3D#{name}"}
    {list_op, params}
  end
end
