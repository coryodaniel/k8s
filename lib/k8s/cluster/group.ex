defmodule K8s.Cluster.Group do
  @moduledoc """
  Kubernetes API Groups
  """

  @doc """
  Finds a resource definition by group version and (name or kind).
  """
  @spec find_resource(atom(), binary(), atom() | binary()) ::
          {:ok, map}
          | {:error, :unsupported_resource, binary()}
          | {:error, :unsupported_group_version, binary()}
  def find_resource(cluster_name, group_version, name_or_kind) do
    case :ets.lookup(K8s.Cluster.Group, cluster_key(cluster_name, group_version)) do
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
    resource = Enum.find(resources, &match_resource_by_name(&1, name_or_kind))

    case resource do
      nil -> {:error, :unsupported_resource, name_or_kind}
      resource -> {:ok, resource}
    end
  end

  @doc """
  Creates a ETS key for `K8s.Cluster.Group` per `K8s.Cluster`

  ## Examples

      iex. K8s.Cluster.Group.cluster_key(:dev, "apps/v1")
      "dev/apps/v1"

  """
  @spec cluster_key(atom, binary) :: binary
  def cluster_key(cluster_name, group_version), do: "#{cluster_name}/#{group_version}"

  @spec match_resource_by_name(map, atom | binary) :: boolean
  defp match_resource_by_name(resource, kind) when is_atom(kind),
    do: match_resource_by_name(resource, Atom.to_string(kind))

  defp match_resource_by_name(%{"name" => name}, name), do: true
  defp match_resource_by_name(%{"kind" => kind}, kind), do: true
  defp match_resource_by_name(%{"kind" => kind}, name), do: String.downcase(kind) == name
end
