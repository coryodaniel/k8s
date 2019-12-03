defmodule K8s.Discovery.Driver.HTTP do
  @moduledoc "HTTP Driver for Kubernetes API discovery"
  @behaviour K8s.Discovery.Driver
  @core_api_base_path "/api"
  @group_api_base_path "/apis"

  @impl true
  def resources(api_version, %K8s.Conn{} = conn) do
    base_path =
      case String.contains?(api_version, "/") do
        true -> @group_api_base_path
        false -> @core_api_base_path
      end

    api_path = Path.join([base_path, api_version])

    with {:ok, %{"resources" => resources}} <- get(conn, api_path) do
      {:ok, resources}
    end
  end

  @impl true
  def versions(conn) do
    with {:ok, api_versions} <- api(conn), {:ok, apis_versions} <- apis(conn) do
      versions = Enum.concat(api_versions, apis_versions)
      {:ok, versions}
    end
  end

  defp api(%K8s.Conn{} = conn) do
    with {:ok, response} <- get(conn, @core_api_base_path),
         versions <- Map.get(response, "versions", []) do
      {:ok, versions}
    end
  end

  defp apis(%K8s.Conn{} = conn) do
    with {:ok, response} <- get(conn, @group_api_base_path),
         groups <- Map.get(response, "groups"),
         versions <- groups_to_versions(groups) do
      {:ok, versions}
    end
  end

  defp groups_to_versions(groups) do
    Enum.reduce(groups, [], fn group, acc ->
      group["versions"]
      |> Enum.map(fn %{"groupVersion" => gv} -> gv end)
      |> Enum.concat(acc)
    end)
  end

  defp get(conn, path) do
    case K8s.Conn.RequestOptions.generate(conn) do
      {:ok, request_options} ->
        url = Path.join(conn.url, path)
        headers = K8s.http_provider().headers(:get, request_options)
        opts = [ssl: request_options.ssl_options]
        K8s.http_provider().request(:get, url, "", headers, opts)

      error ->
        error
    end
  end
end
