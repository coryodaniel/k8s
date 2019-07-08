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
          | {:error, :unsupported_resource, binary()}
          | {:error, :unsupported_group_version, binary()}
  def find_resource(cluster, group_version, name_or_kind) do
    # key = Atom.to_string(cluster)
    # resources_by_group = :ets.lookup(K8s.Cluster.Group, key)

    case :ets.lookup(K8s.Cluster.Group, lookup_key(cluster, group_version)) do
      [] ->
        {:error, :unsupported_group_version, group_version}

      [{_, _group_version, resources}] ->
        find_resource_by_name(resources, name_or_kind)
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
    # key = Atom.to_string(cluster)
    # :ets.insert(K8s.Cluster.Group, {key, resources_by_group})

    Enum.each(resources_by_group, fn {group, resources} ->
      key = lookup_key(cluster, group)
      :ets.insert(K8s.Cluster.Group, {key, group, resources})
    end)

    :ok
  end

  # Creates an ETS key for `K8s.Cluster.Group` per `K8s.Cluster`
  @spec lookup_key(atom, binary) :: binary
  defp lookup_key(cluster_name, group_version), do: "#{cluster_name}/#{group_version}"
end
