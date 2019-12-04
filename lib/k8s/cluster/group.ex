defmodule K8s.Cluster.Group do
  @moduledoc """
  Kubernetes API Groups
  """

  alias K8s.Cluster.Group.ResourceNaming

  @doc """
  Get the REST resource name for a kubernetes Kind.

  Since `K8s.Operation` is abstracted away from a specific cluster, when working with kubernetes resource `Map`s and specifying `"kind"` the `K8s.Operation.Path` module isn't
  able to determine the correct path. (It will generate things like /api/v1/Pod instead of api/v1/pods).

  Also accepts REST resource name in the event they are provided, as it may be known in the event of subresources.
  """
  @spec resource_name_for_kind(atom(), binary(), binary()) ::
          {:ok, binary()}
          | {:error, :cluster_not_registered, atom()}
          | {:error, :unsupported_resource, binary()}
          | {:error, :unsupported_api_version, binary()}
  def resource_name_for_kind(cluster, api_version, name_or_kind) do
    case find_resource(cluster, api_version, name_or_kind) do
      {:ok, %{"name" => name}} ->
        {:ok, name}

      error ->
        error
    end
  end

  @doc """
  Returns a list of all resources in a given groupVersion
  """
  @spec resources_by_group(atom(), binary()) ::
          {:ok, list(map())}
          | {:error, :cluster_not_registered, atom()}
          | {:error, :unsupported_api_version, binary()}
  def resources_by_group(cluster, api_version) do
    K8s.refactor(__ENV__)

    {:ok, conn} = K8s.Cluster.conn(cluster)
    {:ok, resources} = conn.discovery_driver.resources(api_version, conn)
    {:ok, resources}
    # case :ets.lookup(K8s.Cluster.Group, lookup_key(cluster)) do
    #   [] ->
    #     {:error, :cluster_not_registered, cluster}

    #   [{_cluster_key, resources_by_group}] ->
    #     case Map.get(resources_by_group, api_version) do
    #       nil -> {:error, :unsupported_api_version, api_version}
    #       resources -> {:ok, resources}
    #     end
    # end
  end

  @doc """
  Finds a resource definition by api version and (name or kind).
  """
  @spec find_resource(atom(), binary(), atom() | binary()) ::
          {:ok, map}
          | {:error, :cluster_not_registered, atom()}
          | {:error, :unsupported_resource, binary()}
          | {:error, :unsupported_api_version, binary()}
  def find_resource(cluster, api_version, name_or_kind) do
    with {:ok, resources} <- resources_by_group(cluster, api_version) do
      find_resource_by_name(resources, name_or_kind)
    end
  end

  @doc """
  Insert/Update a cluster's group/resource definitions.
  """
  @spec insert_all(atom(), map()) :: boolean()
  def insert_all(cluster, resources_by_group) do
    K8s.refactor(__ENV__)
    # :ets.insert(K8s.Cluster.Group, {lookup_key(cluster), resources_by_group})
    true
  end

  @doc false
  @spec find_resource_by_name(list(map), atom() | binary()) ::
          {:ok, map} | {:error, atom() | binary()}
  def find_resource_by_name(resources, name_or_kind) do
    resource = Enum.find(resources, &ResourceNaming.matches?(&1, name_or_kind))

    case resource do
      nil -> {:error, :unsupported_resource, name_or_kind}
      resource -> {:ok, resource}
    end
  end
end
