defmodule K8s.Client.Runner.Watch do
  @moduledoc """
  `K8s.Client` runner that will watch a resource or resources and stream results back to a process.
  """

  @resource_version_json_path ~w(metadata resourceVersion)

  alias K8s.Client.Runner.Base
  alias K8s.Operation

  @doc """
  Performs a watch request and streams response back to another process.

  `K8s.Client.Runner.Watch` will accept `K8s.Client.get/N` and `K8s.Client.list/N` operations. `*Get* operations will be converted to a *list* operation with `fieldSelector` set the the `metadata.name`.

  ## Examples

  op = K8s.Client.get("apps/v1", "Deployment", namespace: "docker", name: "compose")
  op = K8s.Client.list("v1", "pod", namespace: :all)
  op = K8s.Client.list("v1", "pod", namespace: "default")

  K8s.Client.watch(op, :test, stream_to: self())

  resource_version = 0
  K8s.Client.watch(op, :test, resource_version, stream_to: self())
  """
  @spec run(Operation.t(), binary, keyword(atom)) :: no_return
  def run(operation = %Operation{method: :get}, cluster_name, opts) do
    case get_resource_version(operation, cluster_name) do
      {:ok, rv} -> run(operation, cluster_name, rv, opts)
      error -> error
    end
  end

  # stream_to, recv_timeout
  def run(operation = %Operation{method: :get, id: "list" <> _rest}, cluster_name, rv, opts) do
    opts_w_watch_params = add_watch_params_to_opts(opts, rv)
    Base.run(operation, cluster_name, opts_w_watch_params)
  end

  def run(operation = %Operation{method: :get, id: "get" <> _rest}, cluster_name, rv, opts) do
    # This can' be a transform, needs to be an alternate func for run to execute
    # Convert a get operation to a list w/ fieldSelector
    # https://localhost:6443/api/v1/namespaces/docker/pods?fieldSelector=metadata.name%3Dcompose-api-76c5fcdc46-7kwg4&resourceVersion=0&watch=true
  end

  def run(op, _, _), do: {:error, "Only HTTP GET operations are supported. #{inspect(op)}"}
  def run(op, _, _, _), do: {:error, "Only HTTP GET operations are supported. #{inspect(op)}"}

  defp get_resource_version(operation = %Operation{}, cluster_name) do
    case Base.run(operation, cluster_name) do
      {:ok, payload} ->
        rv = parse_resource_version(payload)
        IO.puts("Getting resource version: #{inspect(payload)}; #{rv}")
        {:ok, rv}

      error ->
        error
    end
  end

  defp add_watch_params_to_opts(opts, rv) do
    params = Map.merge(opts[:params] || %{}, %{"resourceVersion" => rv, "watch" => true})
    Keyword.put(opts, :params, params)
  end

  defp parse_resource_version(payload = %{}),
    do: get_in(payload, @resource_version_json_path) || 0

  defp parse_resource_version(_), do: 0
end
