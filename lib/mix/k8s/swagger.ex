defmodule Mix.Tasks.K8s.Swagger do
  @moduledoc """
  Download a kubernetes swagger spec.
  """
  use Mix.Task

  @switches [version: :string, out: :string]
  @aliases [v: :version, o: :out]
  @defaults [version: "master"]

  @shortdoc "Downloads a k8s swagger spec"
  @spec run([binary()]) :: nil | :ok
  def run(args) do
    {:ok, _started} = Application.ensure_all_started(:httpoison)
    {opts, _, _} = Mix.K8s.parse_args(args, @defaults, switches: @switches, aliases: @aliases)

    url = url(opts[:version])
    version = opts[:version]
    target = target(version, opts[:out])

    with {:ok, response} <- HTTPoison.get(url) do
      Mix.K8s.create_file(response.body, target)
    else
      {:error, msg} -> raise_with_help(msg)
    end
  end

  @spec target(binary, binary) :: binary
  defp target(version, path) do
    case path do
      nil -> "./priv/swagger/#{version}.json"
      path -> path
    end
  end

  @spec url(binary) :: binary
  defp url(version) do
    case version do
      "master" ->
        "https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json"

      version ->
        "https://raw.githubusercontent.com/kubernetes/kubernetes/release-#{version}/api/openapi-spec/swagger.json"
    end
  end

  @spec raise_with_help(binary) :: no_return
  defp raise_with_help(msg) do
    Mix.raise("""
    #{msg}

    mix k8s.swagger downloads a K8s swagger file to priv/swagger/

    Downloading master:
       mix k8s.swagger

    Downloading a specific version:
       mix k8s.swagger --version 1.13

    Downloading to an alternate path:
       mix k8s.swagger --version 1.13 -o /tmp/swagger.json

    Printing to STDOUT:
       mix k8s.swagger --version 1.13 -o -
    """)
  end
end
