defmodule K8s.Discovery.Driver.HTTP do
  @moduledoc "HTTP Driver for Kubernetes API discovery"
  @behaviour K8s.Discovery.Driver
  @core_api_base_path "/api"
  @group_api_base_path "/apis"

  @impl true
  def resources(api_version, %K8s.Conn{} = conn, _opts \\ []) do
    base_path =
      case String.contains?(api_version, "/") do
        true -> @group_api_base_path
        false -> @core_api_base_path
      end

    api_path = Path.join([base_path, api_version])

    with {:ok, %{"resources" => resources}} <- http_get(conn, api_path) do
      {:ok, resources}
    end
  end

  @impl true
  def versions(%K8s.Conn{} = conn, _opts \\ []) do
    with {:ok, api_versions} <- api(conn), {:ok, apis_versions} <- apis(conn) do
      versions = Enum.concat(api_versions, apis_versions)
      {:ok, versions}
    end
  end

  @spec api(K8s.Conn.t()) :: {:ok, list(String.t())} | K8s.Client.Provider.error_t()
  defp api(%K8s.Conn{} = conn) do
    with {:ok, response} <- http_get(conn, @core_api_base_path),
         versions <- Map.get(response, "versions", []) do
      {:ok, versions}
    end
  end

  @spec apis(K8s.Conn.t()) :: {:ok, list(String.t())} | K8s.Client.Provider.error_t()
  defp apis(%K8s.Conn{} = conn) do
    with {:ok, response} <- http_get(conn, @group_api_base_path),
         groups <- Map.get(response, "groups"),
         versions <- groups_to_versions(groups) do
      {:ok, versions}
    end
  end

  @spec groups_to_versions(list(map)) :: list(String.t())
  defp groups_to_versions(groups) do
    Enum.reduce(groups, [], fn group, acc ->
      group["versions"]
      |> Enum.map(fn %{"groupVersion" => gv} -> gv end)
      |> Enum.concat(acc)
    end)
  end

  @spec http_get(K8s.Conn.t(), String.t()) :: K8s.Client.Provider.response_t()
  defp http_get(conn, path) do
    case K8s.Conn.RequestOptions.generate(conn) do
      {:ok, request_options} ->
        uri = conn.url |> Path.join(path) |> URI.parse()
        headers = K8s.Client.Provider.headers(request_options)
        opts = [ssl: request_options.ssl_options]
        conn.http_provider.request(:get, uri, nil, headers, opts)

      error ->
        error
    end
  end
end
