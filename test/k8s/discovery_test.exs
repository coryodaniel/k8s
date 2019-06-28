# credo:disable-for-this-file
defmodule K8s.DiscoveryTest do
  use ExUnit.Case, async: true
  alias K8s.Mock.DynamicHTTPProvider

  defmodule HTTPMock do
    @base_url "https://localhost:6443"
    import K8s.Test.HTTPHelper

    def request(:get, @base_url <> "/api", _, _, _) do
      render(%{"versions" => ["v1"]})
    end

    def request(:get, @base_url <> "/apis", _, _, _) do
      groups = [
        %{
          "name" => "apps",
          "preferredVersion" => %{"groupVersion" => "apps/v1", "version" => "v1"},
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

  test "api_paths/1" do
    api_paths = K8s.Discovery.api_paths(:test)
    assert api_paths == %{"/api" => ["v1"], "/apis" => ["apps/v1", "batch/v1"]}
  end

  test "resource_definitions_by_group/2" do
    resource_definitions = K8s.Discovery.resource_definitions_by_group(:test)

    assert resource_definitions == [
             %{
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
                 }
               ]
             },
             %{
               "apiVersion" => "v1",
               "groupVersion" => "batch/v1",
               "kind" => "APIResourceList",
               "resources" => [
                 %{
                   "kind" => "Job",
                   "name" => "jobs"
                 }
               ]
             },
             %{
               "groupVersion" => "v1",
               "kind" => "APIResourceList",
               "resources" => [
                 %{
                   "kind" => "Namespace",
                   "name" => "namespaces"
                 }
               ]
             }
           ]
  end
end
