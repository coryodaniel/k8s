defmodule K8s.Discovery.Driver.File do
  @moduledoc "File Driver for Kubernetes API discovery"
  @behaviour K8s.Discovery.Driver

  # TODO: replace stubs w/ file access
  # One file apiVersion => APIResourceList...

  @impl true
  def resources(api_version, %K8s.Conn{}) do
    {:ok, get_resources(api_version)}
  end

  @impl true
  def versions(%K8s.Conn{}) do
    {:ok, get_versions()}
  end

  defp get_versions() do
    ["v1", "apps/v1"]
  end

  defp get_resources("apps/v1") do
    [
      %{
        "kind" => "DaemonSet",
        "name" => "daemonsets"
      },
      %{
        "kind" => "Deployment",
        "name" => "deployments"
      },
      %{
        "kind" => "Deployment",
        "name" => "deployments/status"
      }
    ]
  end
end
