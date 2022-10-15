defmodule K8s.Discovery.ResourceFinder do
  @moduledoc """
  Kubernetes API Groups
  """

  alias K8s.Discovery.ResourceNaming

  @type error_t :: {:error, K8s.Discovery.Error.t()}

  @doc """
  Get the REST resource name for a kubernetes `Kind`.

  Since `K8s.Operation` is abstracted away from a specific cluster, when working with kubernetes resource `Map`s and specifying `"kind"` the `K8s.Operation.Path` module isn't
  able to determine the correct path. (It will generate things like /api/v1/Pod instead of api/v1/pods).

  Also accepts REST resource name in the event they are provided, as it may be known in the event of subresources.
  """
  @spec resource_name_for_kind(K8s.Conn.t(), binary(), binary()) ::
          {:ok, binary()}
          | error_t
  def resource_name_for_kind(conn, api_version, name_or_kind) do
    case find_resource(conn, api_version, name_or_kind) do
      {:ok, %{"name" => name}} ->
        {:ok, name}

      error ->
        error
    end
  end

  @doc """
  Finds a resource definition by api version and (name or kind).
  """
  @spec find_resource(K8s.Conn.t(), binary(), atom() | binary()) ::
          {:ok, map}
          | error_t
  def find_resource(conn, api_version, name_or_kind) do
    with {:ok, resources} <- conn.discovery_driver.resources(api_version, conn) do
      find_resource_by_name(resources, name_or_kind)
    end
  end

  @doc false
  @spec find_resource_by_name(list(map), atom() | binary()) ::
          {:ok, map} | error_t
  def find_resource_by_name(resources, name_or_kind) do
    resource = Enum.find(resources, &ResourceNaming.matches?(&1, name_or_kind))

    case resource do
      nil ->
        {:error,
         %K8s.Discovery.Error{
           message: "Unsupported Kubernetes resource: #{inspect(name_or_kind)}"
         }}

      resource ->
        {:ok, resource}
    end
  end
end
