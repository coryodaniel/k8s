defmodule K8s.Cluster.Discovery do
  @moduledoc """
  Interface for `K8s.Cluster` discovery.

  This module implements `K8s.Cluster.Discovery.Driver` behaviour and delegates function calls
  to the configured `@driver`.

  This defaults to the `K8s.Cluster.Discovery.HTTPDriver`, but can be set with:

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

  @doc """
  Lists all identifiers in group from Kubernetes resource definitions returned from `resource_definitions/2`.

  ## Examples
      iex> K8s.Cluster.Discovery.resource_identifiers(:test, "apps/v1")
      [{"apps/v1", "Deployment", "deployments/status"}, {"apps/v1", "Deployment", "deployments"}]
  """
  @spec resource_identifiers_by_group(atom(), binary(), Keyword.t() | nil) ::
          {:ok, list(resource_definition_identifier_t)} | {:error, atom()}
  def resource_identifiers_by_group(cluster, group, opts \\ []) do
    with {:ok, identifiers} <- resource_identifiers(cluster, opts) do
      {:ok, filter_resource_identifiers_by_group(identifiers, group)}
    end
  end

  @spec filter_resource_identifiers_by_group(resource_definition_identifier_t(), binary()) ::
          list(resource_definition_identifier_t())
  defp filter_resource_identifiers_by_group(resource_identifiers, group) do
    Enum.filter(resource_identifiers, fn {g, _, _} -> g == group end)
  end

  @spec get_identifiers_from_resource_definitions(list(map())) ::
          list(resource_definition_identifier_t)
  defp get_identifiers_from_resource_definitions(definitions) do
    Enum.reduce(definitions, [], fn %{"groupVersion" => gv, "resources" => resources}, acc ->
      resource_identifiers =
        Enum.map(resources, fn %{"kind" => kind, "name" => name} ->
          {gv, kind, name}
        end)

      acc ++ resource_identifiers
    end)
  end
end
