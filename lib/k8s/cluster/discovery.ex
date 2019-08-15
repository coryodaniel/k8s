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

  @spec reduce_by_group(list(map())) :: map()
  defp reduce_by_group(groups) do
    Enum.reduce(groups, %{}, fn %{"groupVersion" => gv, "resources" => resources}, acc ->
      Map.put(acc, gv, resources)
    end)
  end
end
