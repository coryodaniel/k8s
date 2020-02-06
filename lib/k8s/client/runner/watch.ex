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
  {:ok, conn} = K8s.Conn.lookup(:test)
  operation = K8s.Client.list("v1", "Namespace")
  {:ok, reference} = Watch.run(operation, conn, stream_to: self())
  ```

  ```elixir
  {:ok, conn} = K8s.Conn.lookup(:test)
  operation = K8s.Client.get("v1", "Namespace", [name: "test"])
  {:ok, reference} = Watch.run(operation, conn, stream_to: self())
  ```
  """
  @spec run(Operation.t(), K8s.Conn.t(), keyword(atom)) :: Base.result_t()
  def run(%Operation{method: :get} = operation, conn, opts) do
    case get_resource_version(operation, conn) do
      {:ok, rv} -> run(operation, conn, rv, opts)
      error -> error
    end
  end

  def run(op, _, _),
    do: {:error, "Only HTTP GET operations (list, get) are supported. #{inspect(op)}"}

  @doc """
  Watch a resource or list of resources from a specific resource version. Provide the `stream_to` option or results will be stream to `self()`.

  ## Examples

  ```elixir
  {:ok, conn} = K8s.Conn.lookup(:test)
  operation = K8s.Client.list("v1", "Namespace")
  resource_version = 3003
  {:ok, reference} = Watch.run(operation, conn, resource_version, stream_to: self())
  ```

  ```elixir
  {:ok, conn} = K8s.Conn.lookup(:test)
  operation = K8s.Client.get("v1", "Namespace", [name: "test"])
  resource_version = 3003
  {:ok, reference} = Watch.run(operation, conn, resource_version, stream_to: self())
  ```
  """
  @spec run(Operation.t(), K8s.Conn.t(), binary, keyword(atom)) :: Base.result_t()
  def run(%Operation{method: :get, verb: verb} = operation, conn, rv, opts)
      when verb in [:list, :list_all_namespaces] do
    opts_w_watch_params = add_watch_params_to_opts(opts, rv)
    Base.run(operation, conn, opts_w_watch_params)
  end

  def run(%Operation{method: :get, verb: :get} = operation, conn, rv, opts) do
    {list_op, field_selector_param} = get_to_list(operation)

    params = Map.merge(opts[:params] || %{}, field_selector_param)
    opts = Keyword.put(opts, :params, params)
    run(list_op, conn, rv, opts)
  end

  def run(op, _, _, _),
    do: {:error, "Only HTTP GET operations (list, get) are supported. #{inspect(op)}"}

  @spec get_resource_version(Operation.t(), K8s.Conn.t()) :: {:ok, binary} | {:error, binary}
  defp get_resource_version(%Operation{} = operation, conn) do
    case Base.run(operation, conn) do
      {:ok, payload} ->
        rv = parse_resource_version(payload)
        {:ok, rv}

      error ->
        error
    end
  end

  @spec add_watch_params_to_opts(keyword, binary) :: keyword
  defp add_watch_params_to_opts(opts, rv) do
    params = Map.merge(opts[:params] || %{}, %{"resourceVersion" => rv, "watch" => true})
    Keyword.put(opts, :params, params)
  end

  @spec parse_resource_version(any) :: binary
  defp parse_resource_version(%{} = payload),
    do: get_in(payload, @resource_version_json_path) || "0"

  defp parse_resource_version(_), do: "0"

  defp get_to_list(get_op) do
    list_op = %{get_op | verb: :list, path_params: []}
    name = get_op.path_params[:name]
    params = %{"fieldSelector" => "metadata.name%3D#{name}"}
    {list_op, params}
  end
end
