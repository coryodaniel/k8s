defmodule K8s.Test.IntegrationHelper do
  @moduledoc "Kubernetes integration helpers for test suite"

  @spec conn() :: K8s.Conn.t()
  def conn do
    {:ok, conn} =
      "TEST_KUBECONFIG"
      |> System.get_env()
      |> K8s.Conn.from_file()

    # Override the defaults for testing
    %K8s.Conn{
      conn
      | discovery_driver: K8s.Discovery.Driver.HTTP,
        discovery_opts: [],
        http_provider: K8s.Client.HTTPProvider
    }
  end

  @spec build_pod(String.t(), Map.t()) :: Map.t()
  def build_pod(name, labels \\ %{}) do
    %{
      "apiVersion" => "v1",
      "kind" => "Pod",
      "metadata" => %{
        "name" => name,
        "namespace" => "default",
        "labels" => labels
      },
      "spec" => %{
        "containers" => [
          %{"image" => "nginx", "name" => "nginx"}
        ]
      }
    }
  end

  @doc "Kubernetes Namespace manifest"
  @spec build_namespace(binary) :: map
  def build_namespace(name) do
    %{
      "apiVersion" => "v1",
      "metadata" => %{"name" => name},
      "kind" => "Namespace"
    }
  end

  @doc "Kubernetes Service manifest stub"
  @spec build_service(binary, binary | nil) :: map
  def build_service(name, ns \\ "default") do
    %{
      "kind" => "Service",
      "apiVersion" => "v1",
      "metadata" => %{"name" => name, "namespace" => ns}
    }
  end

  @doc "Kubernetes list manifest stub"
  @spec build_list(list, binary | nil) :: map
  def build_list(items, continue \\ "") do
    %{
      "metadata" => %{"continue" => continue},
      "items" => items
    }
  end
end
