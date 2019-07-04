defmodule K8s.Cluster.Discovery.HTTPDriver do
  @moduledoc """
  `K8s.Cluster.Discovery.Driver` implementation that makes calls to Kubernetes REST API.
  """

  @behaviour K8s.Cluster.Discovery.Driver
  @core_api_base_path "/api"
  @group_api_base_path "/apis"

  alias K8s.{Cluster, Conf, Config}
  alias K8s.Conf.RequestOptions

  @impl true
  def resource_definitions(cluster, opts \\ []) do
    timeout = Config.discovery_http_timeout(cluster)
    opts = Keyword.merge([timeout: timeout, recv_timeout: timeout], opts)

    with {:ok, conf} <- Cluster.conf(cluster),
         {:ok, api_versions} <- api_versions(cluster, opts) do
      {:ok, get_resource_definitions(api_versions, conf, opts)}
    end
  end

  @impl true
  def api_versions(cluster, opts \\ []) do
    with {:ok, api} <- api(cluster, opts),
         {:ok, apis} <- apis(cluster, opts) do
      {:ok, api ++ apis}
    end
  end

  # list Core/Legacy APIs
  @spec api(atom, Keyword.t()) :: {:ok, list(binary())} | {:error, atom()}
  defp api(cluster, opts) do
    with {:ok, conf} <- Cluster.conf(cluster),
         url <- Path.join(conf.url, @core_api_base_path),
         {:ok, response} <- get(url, conf, opts),
         versions <- Map.get(response, "versions") do
      {:ok, versions}
    end
  end

  # list Named Group / Custom Resource APIs
  @spec apis(atom, Keyword.t()) :: {:ok, list(binary())} | {:error, atom()}
  defp apis(cluster, opts) do
    with {:ok, conf} <- Cluster.conf(cluster),
         url <- Path.join(conf.url, @group_api_base_path),
         {:ok, response} <- get(url, conf, opts),
         groups <- Map.get(response, "groups") do
      group_versions = get_group_versions_from_groups(groups)

      {:ok, group_versions}
    end
  end

  @spec get_group_versions_from_groups(list(map())) :: list(binary())
  defp get_group_versions_from_groups(groups) do
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
        headers = K8s.http_provider().headers(:get, request_options)
        opts = Keyword.merge([ssl: request_options.ssl_options], opts)

        K8s.http_provider().request(:get, url, "", headers, opts)

      error ->
        error
    end
  end

  @spec get_resource_definitions(list(binary()), K8s.Conf.t(), Keyword.t()) :: list(map())
  defp get_resource_definitions(api_versions, conf, opts) do
    timeout = Keyword.get(opts, :timeout) || 5000

    api_versions
    |> Enum.reduce([], fn api_version, acc ->
      task = get_api_version_resources(api_version, conf, opts)
      [task | acc]
    end)
    |> Enum.map(fn task -> Task.await(task, timeout) end)
    |> List.flatten()
  end

  @spec get_api_version_resources(binary(), K8s.Conf.t(), Keyword.t()) :: Task.t()
  defp get_api_version_resources(api_version, conf, opts) do
    Task.async(fn ->
      base_path =
        case String.contains?(api_version, "/") do
          true -> @group_api_base_path
          false -> @core_api_base_path
        end

      url = Path.join([conf.url, base_path, api_version])

      case get(url, conf, opts) do
        {:ok, resource_definition} ->
          resource_definition

        _ ->
          []
      end
    end)
  end
end
