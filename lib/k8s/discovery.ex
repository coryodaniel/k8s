defmodule K8s.Discovery do
  @moduledoc """
  Auto discovery of Kubenetes API Versions and Groups.
  """

  alias K8s.Cluster
  alias K8s.Conf.RequestOptions

  @doc """
  List all versions supported by cluster

  ## Examples

      iex> K8s.Discovery.versions(:test)
      ["v1", "apiregistration.k8s.io/v1", "apiregistration.k8s.io/v1beta1", "extensions/v1beta1", "apps/v1", "apps/v1beta2", "apps/v1beta1", "events.k8s.io/v1beta1", "authentication.k8s.io/v1", "authentication.k8s.io/v1beta1", "authorization.k8s.io/v1", "authorization.k8s.io/v1beta1", "autoscaling/v1", "autoscaling/v2beta1", "batch/v1", "batch/v1beta1", "certificates.k8s.io/v1beta1", "networking.k8s.io/v1", "policy/v1beta1", "rbac.authorization.k8s.io/v1", "rbac.authorization.k8s.io/v1beta1", "storage.k8s.io/v1", "storage.k8s.io/v1beta1", "admissionregistration.k8s.io/v1beta1", "apiextensions.k8s.io/v1beta1", "hello-operator.example.com/v1", "compose.docker.com/v1beta2", "compose.docker.com/v1beta1"]

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
