defmodule K8s.API do
  alias K8s.Cluster
  alias K8s.Conf.RequestOptions

  @doc """
  List all versions supported by cluster
  """
  def versions(cluster_name, opts \\ []) do
    cluster_name
    |> list_async(opts)
    |> Enum.map(fn {_, versions} -> versions end)
    |> List.flatten()
  end

  @doc """
  List all groups with resources types supported by cluster
  """
  def groups(cluster_name, opts \\ []) do
    conf = Cluster.conf(cluster_name)

    cluster_name
    |> list_async(opts)
    |> Enum.into(%{})
    |> Enum.reduce([], fn {url, versions}, acc ->
      versions
      |> Enum.map(&async_get_resource(url, &1, conf, opts))
      |> Enum.concat(acc)
    end)
    |> Enum.map(&Task.await/1)
    |> List.flatten()
  end

  @doc false
  def api(cluster_name, opts \\ []) do
    conf = Cluster.conf(cluster_name)

    url = Path.join(conf.url, "/api")

    case do_run(url, conf, opts) do
      {:ok, %{"versions" => versions}} -> {url, versions}
      error -> error
    end
  end

  @doc false
  def apis(cluster_name, opts \\ []) do
    conf = Cluster.conf(cluster_name)
    url = Path.join(conf.url, "/apis")

    case do_run(url, conf, opts) do
      {:ok, %{"groups" => groups}} -> {url, group_versions(groups)}
      error -> error
    end
  end

  defp list_async(cluster_name, opts) do
    [:api, :apis]
    |> Enum.map(&Task.async(fn -> apply(__MODULE__, &1, [cluster_name, opts]) end))
    |> Enum.map(&Task.await/1)
  end

  @doc false
  def async_get_resource(url, version, conf, opts) do
    Task.async(fn ->
      url = Path.join(url, version)

      case do_run(url, conf, opts) do
        {:ok, spec} -> spec
        error -> []
      end
    end)
  end

  defp group_versions(groups) do
    Enum.reduce(groups, [], fn group, acc ->
      group_versions = Enum.map(group["versions"], fn %{"groupVersion" => gv} -> gv end)
      acc ++ group_versions
    end)
  end

  def do_run(url, conf, opts) do
    request_options = RequestOptions.generate(conf)
    headers = headers(request_options)
    opts = Keyword.merge([ssl: request_options.ssl_options], opts)

    response = HTTPoison.get(url, headers, opts)
    handle_response(response)
  end

  defp headers(ro = %RequestOptions{}) do
    ro.headers ++ [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  end

  defp handle_response(response) do
    case response do
      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 200..299 ->
        {:ok, decode(body)}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, :unauthorized}

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 400..499 ->
        {:error, "HTTP Error: #{code}; #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP Client Error: #{reason}"}
    end
  end

  defp decode(body) do
    case Jason.decode(body) do
      {:ok, data} -> data
      {:error, _} -> nil
    end
  end
end
