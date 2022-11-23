# credo:disable-for-this-file
defmodule K8s.Client.Runner.StreamTest do
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.Stream
  doctest K8s.Client.Runner.Stream.ListRequest
  alias K8s.Client.Runner.Stream
  alias K8s.Client.DynamicHTTPProvider

  defmodule HTTPMock do
    @base_url "https://localhost:6443"
    @namespaced_url @base_url <> "/api/v1/namespaces"
    import K8s.Test.HTTPHelper
    import K8s.Test.IntegrationHelper

    def request(:get, @namespaced_url <> "/stream-empty-test/services", _body, _headers, _opts) do
      data = build_list([])
      render(data, 200)
    end

    def request(:get, @namespaced_url <> "/stream-failure-test/services", _, _, opts) do
      params = opts[:params]
      page1_items = [build_service("foo", "stream-failure-test")]
      continue_token = "stream-failure-test"

      case params do
        [limit: 10, continue: nil, labelSelector: "", fieldSelector: ""] ->
          data = build_list(page1_items, continue_token)
          render(data, 200, [{"Content-Type", "application/json"}])

        [limit: 10, continue: "stream-failure-test", labelSelector: "", fieldSelector: ""] ->
          render(%{"reason" => "NotFound", "message" => "next page not found"}, 404, [
            {"Content-Type", "application/json"}
          ])
      end
    end

    def request(:get, @namespaced_url <> "/stream-runner-test/services", _, _, opts) do
      params = opts[:params]
      page1_items = [build_service("foo", "stream-runner-test")]
      page2_items = [build_service("bar", "stream-runner-test")]
      page3_items = [build_service("qux", "stream-runner-test")]

      body =
        case params do
          [limit: 10, continue: nil, labelSelector: "", fieldSelector: ""] ->
            build_list(page1_items, "start")

          [limit: 10, continue: "start", labelSelector: "", fieldSelector: ""] ->
            build_list(page2_items, "end")

          [limit: 10, continue: "end", labelSelector: "", fieldSelector: ""] ->
            build_list(page3_items)
        end

      render(body, 200)
    end
  end

  setup do
    DynamicHTTPProvider.register(self(), __MODULE__.HTTPMock)
    {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
    {:ok, %{conn: conn}}
  end

  describe "run/3 :connect" do
    test "stream single line", %{conn: conn} do
      connect_op = K8s.Client.connect("v1", "pods/exec", namespace: "default", name: "nginx")

      operation =
        K8s.Operation.put_query_param(connect_op,
          command: ["/bin/sh", "-c", "date"],
          stdin: true,
          stdout: true,
          stderr: true,
          tty: true
        )

      assert {:ok, stream} = Stream.run(conn, operation, stream_to: self())
      assert Enum.take(stream, 1) == ["Fri Apr 17 23:55:24 UTC 2020\n"]
    end

    test "multiple lines", %{conn: conn} do
      connect_op = K8s.Client.connect("v1", "pods/exec", namespace: "default", name: "nginx")

      runner = fn _, _, opts ->
        msg =
          "total 2\r\ndrwxr-xr-x   2 root root 4096 Nov 14 00:00 bin\r\ndrwxr-xr-x   2 root root 4096 Sep  3 12:10 boot\r\n"

        IO.inspect(opts[:stream_to])
        Process.send_after(opts[:stream_to], {:ok, msg}, 1)
        {:ok, self()}
      end

      operation =
        K8s.Operation.put_query_param(connect_op,
          command: ["/bin/sh", "-c", "ls -l"],
          stdin: true,
          stdout: true,
          stderr: true,
          tty: true
        )

      {:ok, stream} = Stream.run(conn, operation, run: runner)
      assert ["total 2" | lines] = Enum.take(stream, 3)
      assert length(lines) == 2
    end
  end

  describe "run/3 :list" do
    test "when the initial request has no results", %{conn: conn} do
      operation = K8s.Client.list("v1", "Service", namespace: "stream-empty-test")
      assert {:ok, stream} = Stream.run(conn, operation)

      services = Enum.into(stream, [])
      assert services == []
    end

    test "puts error tuples into the stream when HTTP errors are encountered", %{conn: conn} do
      operation = K8s.Client.list("v1", "Service", namespace: "stream-failure-test")
      assert {:ok, stream} = Stream.run(conn, operation)

      services = Enum.into(stream, [])

      assert services == [
               %{
                 "apiVersion" => "v1",
                 "kind" => "Service",
                 "metadata" => %{"name" => "foo", "namespace" => "stream-failure-test"}
               },
               {:error, %K8s.Client.APIError{message: "next page not found", reason: "NotFound"}}
             ]
    end

    test "returns an enumerable stream of k8s resources", %{conn: conn} do
      operation = K8s.Client.list("v1", "Service", namespace: "stream-runner-test")
      assert {:ok, stream} = Stream.run(conn, operation)

      services = Enum.into(stream, [])

      assert services == [
               %{
                 "apiVersion" => "v1",
                 "kind" => "Service",
                 "metadata" => %{"name" => "foo", "namespace" => "stream-runner-test"}
               },
               %{
                 "apiVersion" => "v1",
                 "kind" => "Service",
                 "metadata" => %{"name" => "bar", "namespace" => "stream-runner-test"}
               },
               %{
                 "apiVersion" => "v1",
                 "kind" => "Service",
                 "metadata" => %{"name" => "qux", "namespace" => "stream-runner-test"}
               }
             ]
    end
  end
end
