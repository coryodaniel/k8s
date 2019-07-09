defmodule K8s.Cluster.Discovery do
  @moduledoc """
  Interface for `K8s.Cluster` discovery.

  This module implements `K8s.Cluster.Discovery.Driver` behaviour and delegates function calls
  to the configured `@driver`.

  This defaults to the `K8s.Cluster.Discovery.HTTPDriver`

  The driver can be set with:

  ```elixir
  Application.get_env(:k8s, :discovery_driver, MyCustomDiscoveryDriver)
  ```
  """

  @behaviour K8s.Cluster.Discovery.Driver
  @driver Application.get_env(:k8s, :discovery_driver, K8s.Cluster.Discovery.HTTPDriver)

  @typedoc """
  Resource definition identifier. Format: `{groupVersion, kind, name}`

  Where `kind` is the kubernetes resource type and `name` is the name of the resource, which includes sub-resources.

  E.g.:
  * `{"apps/v1", "Deployment", "deployments"}
  * `{"apps/v1", "Deployment", "deployments/status"}
  """
  @type resource_definition_identifier_t :: {binary(), binary(), binary()}

  @doc """
  Lists Kubernetes `apiVersion`s

  Delegates to the configured driver.
  """
  @impl true
  def api_versions(cluster, opts \\ []), do: @driver.api_versions(cluster, opts)

  @doc """
  Lists Kubernetes `APIResourceList`s

  Delegates to the configured driver.
  """
  @impl true
  def resource_definitions(cluster, opts \\ []), do: @driver.resource_definitions(cluster, opts)

  @doc """
  Get all resources keyed by groupVersion/apiVersion membership.
  """
  @spec resources_by_group(atom(), Keyword.t() | nil) :: {:ok, map()} | {:error, atom()}
  def resources_by_group(cluster, opts \\ []) do
    with {:ok, definitions} <- resource_definitions(cluster, opts),
         by_group <- reduce_by_group(definitions) do
      {:ok, by_group}
    end
  end

  @doc """
  Lists identifiers from Kubernetes resource definitions returned from `resource_definitions/2`.

  ## Examples
      iex> K8s.Cluster.Discovery.resource_identifiers(:test)
      [{"auditregistration.k8s.io/v1alpha1", "AuditSink", "auditsinks"}, {"settings.k8s.io/v1alpha1", "PodPreset", "podpresets"}, {"apiregistration.k8s.io/v1", "APIService", "apiservices"}]
  """
  @spec resource_identifiers(atom(), Keyword.t() | nil) ::
          {:ok, list(resource_definition_identifier_t)} | {:error, atom()}
  def resource_identifiers(cluster, opts \\ []) do
    with {:ok, definitions} <- resource_definitions(cluster, opts) do
      {:ok, get_identifiers_from_resource_definitions(definitions)}
    end
  end

  @spec get_identifiers_from_resource_definitions(list(map())) ::
          list(resource_definition_identifier_t)
  defp get_identifiers_from_resource_definitions(groups) do
    Enum.reduce(groups, [], fn %{"groupVersion" => gv, "resources" => resources}, acc ->
      resource_identifiers =
        Enum.map(resources, fn resource ->
          group_version = resource_group_version(gv, resource)
          {group_version, resource["kind"], resource["name"]}
        end)

      acc ++ resource_identifiers
    end)
  end

  @spec reduce_by_group(list(map())) :: map()
  defp reduce_by_group(groups) do
    Enum.reduce(groups, %{}, fn %{"groupVersion" => gv, "resources" => resources}, acc ->
      Enum.reduce(resources, acc, fn resource, acc ->
        group_version = resource_group_version(gv, resource)
        prev_resources_in_group = Map.get(acc, group_version, [])
        new_resources_in_group = [resource | prev_resources_in_group]
        Map.put(acc, group_version, new_resources_in_group)
      end)
    end)
  end

  @spec resource_group_version(binary(), map) :: binary
  defp resource_group_version(_group_version, %{
         "group" => subresource_group,
         "kind" => _,
         "name" => _,
         "version" => subresource_version
       }),
       do: Path.join(subresource_group, subresource_version)

  defp resource_group_version(group_version, %{"kind" => _, "name" => _}), do: group_version
end
