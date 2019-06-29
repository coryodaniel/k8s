defmodule K8s.Discovery do
  @moduledoc """
  Auto discovery of Kubenetes API Versions and API Groups.
  """

  @behaviour K8s.Behaviours.DiscoveryProvider

  alias K8s.{Cluster, Conf, Config}
  alias K8s.Conf.RequestOptions

  @doc "List all resource definitions by group"
  @impl true
  def resource_definitions_by_group(cluster_name, defaults \\ []) do
    timeout = Config.discovery_http_timeout(cluster_name)
    opts = Keyword.merge([timeout: timeout, recv_timeout: timeout], defaults)

    with {:ok, conf} <- Cluster.conf(cluster_name),
         {:ok, apis} <- api_paths(cluster_name, opts) do
      {:ok, get_resource_definitions(apis, conf, opts)}
    end
  end

  @doc "Get a map of API type to groups"
  @spec api_paths(atom, keyword) :: {:ok, map()} | {:error, binary | atom}
  def api_paths(cluster_name, opts \\ []) do
    with {:ok, conf} <- Cluster.conf(cluster_name),
         api_url <- Path.join(conf.url, "/api"),
         apis_url <- Path.join(conf.url, "/apis"),
         {:ok, api} <- get(api_url, conf, opts),
         {:ok, apis} <- get(apis_url, conf, opts) do
      {:ok,
       %{
         "/api" => api["versions"],
         "/apis" => group_versions(apis["groups"])
       }}
    end
  end

  @spec get_resource_definitions(map(), Conf.t(), Keyword.t()) :: list(map())
  defp get_resource_definitions(apis, conf, opts) do
    timeout = Keyword.get(opts, :timeout)

    apis
    |> Enum.reduce([], fn {prefix, versions}, acc ->
      versions
      |> Enum.map(&async_get_resource_definition(prefix, &1, conf, opts))
      |> Enum.concat(acc)
    end)
    |> Enum.map(fn task -> Task.await(task, timeout) end)
    |> List.flatten()
  end

  @doc """
  Asynchronously fetch resource definitions.

  `Task` will contain a list of resource definitions.

  In the event of failure an empty list is returned.
  """
  @spec async_get_resource_definition(binary, binary, map, keyword) :: %Task{}
  def async_get_resource_definition(prefix, version, conf, opts) do
    Task.async(fn ->
      url = Path.join([conf.url, prefix, version])

      case get(url, conf, opts) do
        {:ok, resource_definition} ->
          resource_definition

        _ ->
          []
      end
    end)
  end

  @spec group_versions(list(map)) :: list(map)
  defp group_versions(groups) do
    Enum.reduce(groups, [], fn group, acc ->
      group_versions = Enum.map(group["versions"], fn %{"groupVersion" => gv} -> gv end)
      acc ++ group_versions
    end)
  end

  @spec get(binary(), Conf.t(), Keyword.t()) ::
          {:ok, HTTPoison.Response.t()} | {:error, atom}
  defp get(url, conf, opts) do
    case RequestOptions.generate(conf) do
      {:ok, request_options} ->
        headers = K8s.http_provider().headers(request_options)
        opts = Keyword.merge([ssl: request_options.ssl_options], opts)

        K8s.http_provider().request(:get, url, "", headers, opts)

      error ->
        error
    end
  end
end
