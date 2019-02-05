defmodule K8s.Discovery do
  @moduledoc """
  Auto discovery of Kubenetes API Versions and Groups.
  """

  @behaviour K8s.Behaviours.DiscoveryProvider

  alias K8s.Cluster
  alias K8s.Conf.RequestOptions

  @doc """
  List all resource definitions by group

  ## Examples
      iex> K8s.Discovery.resource_definitions_by_group(:test)
      [%{"apiVersion" => "v1", "groupVersion" => "apps/v1", "kind" => "APIResourceList", "resources" => [%{"kind" => "DaemonSet", "name" => "daemonsets", "namespaced" => true, "verbs" => ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]}, %{"kind" => "Deployment", "name" => "deployments", "namespaced" => true, "verbs" => ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]}]}, %{"apiVersion" => "v1", "groupVersion" => "batch/v1", "kind" => "APIResourceList", "resources" => [%{"kind" => "Job", "name" => "jobs", "namespaced" => true, "verbs" => ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]}]}, %{"groupVersion" => "v1", "kind" => "APIResourceList", "resources" => [%{"kind" => "Namespace", "name" => "namespaces", "namespaced" => false, "verbs" => ["create", "delete", "get", "list", "patch", "update", "watch"]}]}]
  """
  @impl true
  def resource_definitions_by_group(cluster_name, opts \\ []) do
    {:ok, conf} = Cluster.conf(cluster_name)

    cluster_name
    |> api_paths(opts)
    |> Enum.into(%{})
    |> Enum.reduce([], fn {prefix, versions}, acc ->
      versions
      |> Enum.map(&async_get_resource_definition(prefix, &1, conf, opts))
      |> Enum.concat(acc)
    end)
    |> Enum.map(&Task.await/1)
    |> List.flatten()
  end

  @doc """
  Get a map of API type to groups

  ## Examples
      iex> K8s.Discovery.api_paths(:test)
      %{"/api" => ["v1"], "/apis" => ["apps/v1", "batch/v1"]}
  """
  def api_paths(cluster_name, opts \\ []) do
    {:ok, conf} = Cluster.conf(cluster_name)
    api_url = Path.join(conf.url, "/api")
    apis_url = Path.join(conf.url, "/apis")

    with {:ok, api} <- do_run(api_url, conf, opts),
         {:ok, apis} <- do_run(apis_url, conf, opts) do
      %{
        "/api" => api["versions"],
        "/apis" => group_versions(apis["groups"])
      }
    else
      error -> error
    end
  end

  @doc false
  def async_get_resource_definition(prefix, version, conf, opts) do
    Task.async(fn ->
      url = Path.join([conf.url, prefix, version])

      case do_run(url, conf, opts) do
        {:ok, resource_definition} -> resource_definition
        _ -> []
      end
    end)
  end

  defp group_versions(groups) do
    Enum.reduce(groups, [], fn group, acc ->
      group_versions = Enum.map(group["versions"], fn %{"groupVersion" => gv} -> gv end)
      acc ++ group_versions
    end)
  end

  defp do_run(url, conf, opts) do
    request_options = RequestOptions.generate(conf)
    headers = K8s.http_provider().headers(request_options)
    opts = Keyword.merge([ssl: request_options.ssl_options], opts)

    K8s.http_provider().request(:get, url, "", headers, opts)
  end
end
