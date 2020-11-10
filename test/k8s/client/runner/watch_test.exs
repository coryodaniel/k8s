defmodule K8s.Client.Runner.WatchTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.Watch
  alias K8s.Client.Runner.Watch
  alias K8s.Client.DynamicHTTPProvider

  defmodule HTTPMock do
    @base_url "https://localhost:6443"
    @namespaced_url @base_url <> "/api/v1/namespaces"
    import K8s.Test.HTTPHelper

    def request(:get, @namespaced_url, _body, _headers, opts) do
      case opts[:stream_to] do
        nil ->
          render(nil)

        pid ->
          send(pid, %HTTPoison.AsyncStatus{code: 200})
          send(pid, %HTTPoison.AsyncHeaders{})
          send(pid, %HTTPoison.AsyncChunk{chunk: "Namespace Watcher"})
          send(pid, %HTTPoison.AsyncEnd{})
          render(nil)
      end
    end

    def request(:get, @namespaced_url <> "/test", _, _, _) do
      render(nil)
    end
  end

  setup do
    DynamicHTTPProvider.register(self(), __MODULE__.HTTPMock)
    {:ok, conn} = K8s.Conn.lookup("test")
    {:ok, %{conn: conn}}
  end

  describe "run/4" do
    test "watching a list operation from a specific resource version", %{conn: conn} do
      operation = K8s.Client.list("v1", "Namespace")
      assert {:ok, _} = Watch.run(conn, operation, 0, stream_to: self())

      assert_receive %HTTPoison.AsyncStatus{code: 200}
      assert_receive %HTTPoison.AsyncHeaders{}
      assert_receive %HTTPoison.AsyncChunk{chunk: "Namespace Watcher"}
      assert_receive %HTTPoison.AsyncEnd{}
    end
  end

  describe "run/3" do
    test "watching a list all operation", %{conn: conn} do
      operation = K8s.Client.list("v1", "Namespace")
      assert {:ok, _} = Watch.run(conn, operation, stream_to: self())

      assert_receive %HTTPoison.AsyncStatus{code: 200}
      assert_receive %HTTPoison.AsyncHeaders{}
      assert_receive %HTTPoison.AsyncChunk{chunk: "Namespace Watcher"}
      assert_receive %HTTPoison.AsyncEnd{}
    end

    test "watching a get operation", %{conn: conn} do
      operation = K8s.Client.get("v1", "Namespace", name: "test")
      assert {:ok, _} = Watch.run(conn, operation, stream_to: self())

      assert_receive %HTTPoison.AsyncStatus{code: 200}
      assert_receive %HTTPoison.AsyncHeaders{}
      assert_receive %HTTPoison.AsyncChunk{chunk: "Namespace Watcher"}
      assert_receive %HTTPoison.AsyncEnd{}
    end

    test "returns an error when its not a get or list operation", %{conn: conn} do
      pod = %{
        "apiVersion" => "apps/v1",
        "kind" => "Deployment",
        "metadata" => %{
          "name" => "nginx",
          "namespace" => "test"
        },
        "spec" => %{
          "containers" => %{
            "image" => "nginx",
            "name" => "nginx"
          }
        }
      }

      operation = K8s.Client.create(pod)
      assert {:error, _msg} = Watch.run(conn, operation, stream_to: self())
    end
  end
end
