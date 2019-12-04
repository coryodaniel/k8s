# credo:disable-for-this-file
defmodule K8s.Discovery.Driver.HTTPTest do
  use ExUnit.Case, async: true
  alias K8s.Client.DynamicHTTPProvider

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

    def request(:get, @base_url <> "/apis/apps/v1", _, _, _) do
      resource_list = %{
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

      render(resource_list)
    end
  end

  setup do
    DynamicHTTPProvider.register(self(), __MODULE__.HTTPMock)
  end

  describe "resources/2" do
    test "returns a list of API resources" do
      {:ok, conn} = K8s.Cluster.conn(:test)
      {:ok, resources} = K8s.Discovery.Driver.HTTP.resources("apps/v1", conn)

      assert resources == [
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

  describe "versions/1" do
    test "returns a list of API versions" do
      {:ok, conn} = K8s.Cluster.conn(:test)
      {:ok, versions} = K8s.Discovery.Driver.HTTP.versions(conn)

      sorted_versions = Enum.sort(versions)
      assert sorted_versions == ["apps/v1", "batch/v1", "v1"]
    end
  end
end
