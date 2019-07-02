# credo:disable-for-this-file
defmodule K8s.Cluster.Discovery.HTTPDriverTest do
  use ExUnit.Case, async: true
  alias K8s.Client.DynamicHTTPProvider
  alias K8s.Cluster.Discovery.HTTPDriver

  defmodule HTTPMock do
    @base_url "https://localhost:6443"
    import K8s.Test.HTTPHelper

    def request(:get, @base_url <> "/api", _, _, _) do
      render(%{"versions" => ["v1"]})
    end

    def request(:get, @base_url <> "/apis", _, _, _) do
      groups = [
        %{
          "versions" => [
            %{"groupVersion" => "apps/v1", "version" => "v1"},
            %{"groupVersion" => "batch/v1", "version" => "v1"}
          ]
        }
      ]

      render(%{"apiVersion" => "v1", "groups" => groups})
    end

    def request(:get, @base_url <> "/api/v1", _, _, _) do
      resp = %{
        "groupVersion" => "v1",
        "kind" => "APIResourceList",
        "resources" => [
          %{
            "kind" => "Namespace",
            "name" => "namespaces"
          }
        ]
      }

      render(resp)
    end

    def request(:get, @base_url <> "/apis/apps/v1", _, _, _) do
      resp = %{
        "apiVersion" => "v1",
        "groupVersion" => "apps/v1",
        "kind" => "APIResourceList",
        "resources" => [
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
      }

      render(resp)
    end

    def request(:get, @base_url <> "/apis/batch/v1", _, _, _) do
      render(%{
        "apiVersion" => "v1",
        "groupVersion" => "batch/v1",
        "kind" => "APIResourceList",
        "resources" => [
          %{
            "kind" => "Job",
            "name" => "jobs"
          }
        ]
      })
    end
  end

  setup do
    DynamicHTTPProvider.register(self(), __MODULE__.HTTPMock)
  end

  describe "api_versions/1" do
    test "fetches API versions from the kubernetes API" do
      cluster = :test
      {:ok, api_versions} = HTTPDriver.api_versions(cluster)

      assert Enum.member?(api_versions, "v1")
      assert Enum.member?(api_versions, "apps/v1")
      assert Enum.member?(api_versions, "batch/v1")
    end
  end

  describe "resource_definitions/1" do
    test "returns a list of kubernetes `APIResourceList`s" do
      cluster = :test
      {:ok, resource_definitions} = HTTPDriver.resource_definitions(cluster)

      assert resource_definitions == [
               %{
                 "apiVersion" => "v1",
                 "groupVersion" => "batch/v1",
                 "kind" => "APIResourceList",
                 "resources" => [%{"kind" => "Job", "name" => "jobs"}]
               },
               %{
                 "apiVersion" => "v1",
                 "groupVersion" => "apps/v1",
                 "kind" => "APIResourceList",
                 "resources" => [
                   %{"kind" => "DaemonSet", "name" => "daemonsets"},
                   %{"kind" => "Deployment", "name" => "deployments"},
                   %{"kind" => "Deployment", "name" => "deployments/status"}
                 ]
               },
               %{
                 "groupVersion" => "v1",
                 "kind" => "APIResourceList",
                 "resources" => [%{"kind" => "Namespace", "name" => "namespaces"}]
               }
             ]
    end
  end
end
