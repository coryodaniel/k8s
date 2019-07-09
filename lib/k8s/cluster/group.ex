defmodule K8s.Cluster.Group do
  @moduledoc """
  Kubernetes API Groups
  """

  alias K8s.Cluster.Group.ResourceNaming

  @doc """
  Finds a resource definition by group version and (name or kind).
  """
  @spec find_resource(atom(), binary(), atom() | binary()) ::
          {:ok, map}
          | {:error, :cluster_not_registered, atom()}
          | {:error, :unsupported_resource, binary()}
          | {:error, :unsupported_group_version, binary()}
  def find_resource(cluster, group_version, name_or_kind) do
    with {:ok, resources} <- resources_by_group(cluster, group_version) do
      find_resource_by_name(resources, name_or_kind)
    end
  end

  @doc """
  Returns a list of all resources in a given groupVersion
  """
  @spec resources_by_group(atom(), binary()) ::
          {:ok, list(map())}
          | {:error, :cluster_not_registered, atom()}
          | {:error, :unsupported_group_version, binary()}
  def resources_by_group(cluster, group_version) do
    case :ets.lookup(K8s.Cluster.Group, lookup_key(cluster)) do
      [] ->
        {:error, :cluster_not_registered, cluster}

      [{_cluster_key, resources_by_group}] ->
        case Map.get(resources_by_group, group_version) do
          nil -> {:error, :unsupported_group_version, group_version}
          resources -> {:ok, resources}
        end
    end
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

  @doc """
  Insert/Update a cluster's group/resource definitions.
  """
  @spec insert_all(atom(), map()) :: :ok
  def insert_all(cluster, resources_by_group) do
    :ets.insert(K8s.Cluster.Group, {lookup_key(cluster), resources_by_group})
  end

  @spec lookup_key(atom) :: binary
  defp lookup_key(cluster), do: Atom.to_string(cluster)
end
