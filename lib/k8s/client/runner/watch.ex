defmodule K8s.Client.Runner.Watch do
  @moduledoc """
  `K8s.Client` runner that will watch a resource or resources and stream results back to a process.
  """

  alias K8s.Client.Runner.Base
  alias K8s.Client.Runner.Watch.Stream, as: WatchStream
  alias K8s.Conn
  alias K8s.Operation
  alias K8s.Operation.Error

  @resource_version_json_path ~w(metadata resourceVersion)

  @doc """
  Watches resources and returns an Elixir Stream of events emmitted by kubernetes.

  ### Example

  ```elixir
  {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
  op = K8s.Client.list("v1", "Configmap")
  K8s.Client.Runner.Watch.stream(conn, op) |> Stream.map(&IO.inspect/1) |> Stream.run()
  ```

  ```elixir
  {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
  op = K8s.Client.get("v1", "Configmap", name: "test")
  K8s.Client.Runner.Watch.stream(conn, op) |> Stream.map(&IO.inspect/1) |> Stream.run()
  ```
  """
  @spec stream(Conn.t(), Operation.t(), keyword()) :: K8s.Client.Provider.stream_response_t()
  def stream(conn, operation, http_opts \\ [])

  def stream(conn, %Operation{method: :get, verb: :get} = operation, http_opts) do
    {list_op, field_selector_params} = get_to_list(operation)

    http_opts =
      Keyword.update(
        http_opts,
        :params,
        field_selector_params,
        &Keyword.merge(&1, field_selector_params)
      )

    WatchStream.resource(conn, list_op, http_opts)
  end

  def stream(conn, %Operation{method: :get} = operation, http_opts) do
    WatchStream.resource(conn, operation, http_opts)
  end

  def stream(op, _, _) do
    msg = "Only HTTP GET operations (list, get) are supported. #{inspect(op)}"
    {:error, %Error{message: msg}}
  end

  @spec get_resource_version(Conn.t(), Operation.t()) :: {:ok, binary} | Base.error_t()
  def get_resource_version(%Conn{} = conn, %Operation{} = operation) do
    with {:ok, payload} <- Base.run(conn, operation) do
      rv = parse_resource_version(payload)
      {:ok, rv}
    end
  end

  @spec parse_resource_version(any) :: binary
  defp parse_resource_version(%{} = payload),
    do: get_in(payload, @resource_version_json_path) || "0"

  defp parse_resource_version(_), do: "0"

  @spec get_to_list(Operation.t()) :: {Operation.t(), keyword}
  def get_to_list(get_op) do
    {name, other_path_params} = Keyword.pop(get_op.path_params, :name)
    list_op = %{get_op | verb: :list, path_params: other_path_params}
    field_selector_params = [fieldSelector: "metadata.name=#{name}"]
    {list_op, field_selector_params}
  end
end
