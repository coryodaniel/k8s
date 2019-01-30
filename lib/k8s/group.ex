defmodule K8s.Group do
  @moduledoc """
  Kubernetes API Groups
  """

  @doc """
  Finds a resource definition by group version and kind
  """
  @spec find_resource(binary | atom, binary, binary | atom) ::
          map | {:error, :unsupported_group_version, binary}
  def find_resource(cluster_name, group_version, kind) do
    case :ets.lookup(K8s.Group, cluster_key(cluster_name, group_version)) do
      [] ->
        {:error, :unsupported_group_version, group_version}

      [{_, _group_version, resources}] ->
        find_resource_by_name(resources, kind)
    end
  end

  @doc false
  @spec find_resource_by_name(list(map), binary()) ::
          {:ok, map} | {:error, :unsupported_kind, binary()}
  def find_resource_by_name(resources, kind) do
    resource = Enum.find(resources, &match_resource_by_name(&1, kind))

    case resource do
      nil -> {:error, :unsupported_kind, kind}
      resource -> {:ok, resource}
    end
  end

  @doc """
  Creates a ETS key for `K8s.Group` per `K8s.Cluster`

  ## Examples

      iex. K8s.Group.cluster_key(:dev, "apps/v1")
      "dev/apps/v1"

  """
  @spec cluster_key(binary, binary) :: binary
  def cluster_key(cluster_name, group_version), do: "#{cluster_name}/#{group_version}"

  @spec match_resource_by_name(map, atom | binary) :: boolean
  defp match_resource_by_name(resource, kind) when is_atom(kind),
    do: match_resource_by_name(resource, Atom.to_string(kind))

  defp match_resource_by_name(%{"kind" => kind}, kind), do: true
  defp match_resource_by_name(%{"name" => name}, name), do: true
  defp match_resource_by_name(%{"kind" => kind}, name), do: String.downcase(kind) == name
end
