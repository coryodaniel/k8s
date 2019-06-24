defmodule Mock.HTTPProvider do
  @moduledoc """
  Mock of `K8s.Client.HTTProvider`
  """
  @behaviour K8s.Behaviours.HTTPProvider
  @uri_prefix "https://localhost:6443"

  @impl true
  defdelegate headers(request_options), to: K8s.Client.HTTPProvider

  @impl true
  defdelegate handle_response(resp), to: K8s.Client.HTTPProvider

  @impl true
  def request(:get, @uri_prefix <> "/api", _, _, _) do
    render_ok(%{"versions" => ["v1"]})
  end

  def request(:get, @uri_prefix <> "/apis", _, _, _) do
    groups = [
      %{
        "name" => "apps",
        "preferredVersion" => %{"groupVersion" => "apps/v1", "version" => "v1"},
        "serverAddressByClientCIDRs" => nil,
        "versions" => [
          %{"groupVersion" => "apps/v1", "version" => "v1"},
          %{"groupVersion" => "batch/v1", "version" => "v1"}
        ]
      }
    ]

    group_versions = %{"apiVersion" => "v1", "groups" => groups}
    render_ok(group_versions)
  end

  def request(:get, @uri_prefix <> "/api/v1", _, _, _) do
    resp = %{
      "groupVersion" => "v1",
      "kind" => "APIResourceList",
      "resources" => [
        %{
          "kind" => "Namespace",
          "name" => "namespaces",
          "namespaced" => false,
          "verbs" => [
            "create",
            "delete",
            "get",
            "list",
            "patch",
            "update",
            "watch"
          ]
        }
      ]
    }

    render_ok(resp)
  end

  def request(:get, @uri_prefix <> "/apis/apps/v1", _, _, _) do
    resp = %{
      "apiVersion" => "v1",
      "groupVersion" => "apps/v1",
      "kind" => "APIResourceList",
      "resources" => [
        %{
          "kind" => "DaemonSet",
          "name" => "daemonsets",
          "namespaced" => true,
          "verbs" => [
            "create",
            "delete",
            "deletecollection",
            "get",
            "list",
            "patch",
            "update",
            "watch"
          ]
        },
        %{
          "kind" => "Deployment",
          "name" => "deployments",
          "namespaced" => true,
          "verbs" => [
            "create",
            "delete",
            "deletecollection",
            "get",
            "list",
            "patch",
            "update",
            "watch"
          ]
        }
      ]
    }

    render_ok(resp)
  end

  def request(:get, @uri_prefix <> "/apis/batch/v1", _, _, _) do
    batch_v1_resource_group() |> render_ok
  end

  def request(:get, @uri_prefix <> "/api/v1/namespaces", _, _, opts) do
    case opts[:stream_to] do
      nil ->
        render_ok(nil)

      pid ->
        stream_namespace_watcher_results(pid)
        render_ok(nil)
    end
  end

  def make_continue_response(continue, items) do
    %{
      "metadata" => %{
        "continue" => continue
      },
      "items" => items
    }
  end

  def make_service(name, ns \\ "default") do
    %{
      "kind" => "Service",
      "apiVersion" => "v1",
      "metadata" => %{"name" => name, "namespace" => ns}
    }
  end

  def request(:get, @uri_prefix <> "/api/v1/namespaces/stream-runner-test/services", _, _, opts) do
    params = opts[:params]
    page1_items = [make_service("foo", "stream-runner-test")]
    page2_items = [make_service("bar", "stream-runner-test")]
    page3_items = [make_service("qux", "stream-runner-test")]

    body =
      case params do
        %{continue: nil, limit: limit} -> make_continue_response("start", page1_items)
        %{continue: "start"} -> make_continue_response("end", page2_items)
        %{continue: "end"} -> make_continue_response("", page3_items)
      end

    render_ok(body)
  end

  def request(:get, @uri_prefix <> "/api/v1/namespaces", _, _, opts) do
    render_ok(nil)
  end

  def request(:get, @uri_prefix <> "/api/v1/namespaces/test", _, _, _) do
    render_ok(nil)
  end

  def request(:post, @uri_prefix <> "/api/v1/namespaces", _, _, _) do
    render_ok(nil)
  end

  def request(method, url, _body, _headers, _opts) do
    raise "#{__MODULE__} has no mock for [#{method}] #{url}"
  end

  @spec render_ok(map) :: nil
  def render_ok(nil), do: render_ok("Not what you expected? Did you set the http_provider mock?")

  def render_ok(data) do
    body = Jason.encode!(data)
    handle_response({:ok, %HTTPoison.Response{status_code: 200, body: body}})
  end

  @spec stream_namespace_watcher_results(map) :: nil
  defp stream_namespace_watcher_results(pid) do
    send(pid, %HTTPoison.AsyncStatus{code: 200})
    send(pid, %HTTPoison.AsyncHeaders{})
    send(pid, %HTTPoison.AsyncChunk{chunk: "Namespace Watcher"})
    send(pid, %HTTPoison.AsyncEnd{})
  end

  @spec batch_v1_resource_group() :: map
  defp batch_v1_resource_group() do
    %{
      "apiVersion" => "v1",
      "groupVersion" => "batch/v1",
      "kind" => "APIResourceList",
      "resources" => [
        %{
          "kind" => "Job",
          "name" => "jobs",
          "namespaced" => true,
          "verbs" => [
            "create",
            "delete",
            "deletecollection",
            "get",
            "list",
            "patch",
            "update",
            "watch"
          ]
        }
      ]
    }
  end
end
