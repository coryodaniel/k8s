# credo:disable-for-this-file
defmodule K8s.Client.Runner.StreamTest do
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.Stream
  doctest K8s.Client.Runner.Stream.ListRequest
  alias K8s.Client.Runner.Stream
  alias K8s.Client.DynamicHTTPProvider

  defmodule HTTPMock do
    @namespaced_path "/api/v1/namespaces"
    import K8s.Test.IntegrationHelper

    def request(
          :get,
          %URI{path: @namespaced_path <> "/stream-empty-test/services"},
          _body,
          _headers,
          _opts
        ) do
      data = build_list([])
      {:ok, data}
    end

    def request(:get, %URI{path: @namespaced_path <> "/stream-failure-test/services"}, _, _, opts) do
      params = opts[:params]
      page1_items = [build_service("foo", "stream-failure-test")]
      continue_token = "stream-failure-test"

      case params do
        [limit: 10, continue: nil] ->
          data = build_list(page1_items, continue_token)
          {:ok, data}

        [limit: 10, continue: "stream-failure-test"] ->
          {:error, %K8s.Client.APIError{reason: "NotFound", message: "next page not found"}}
      end
    end

    def request(:get, %URI{path: @namespaced_path <> "/stream-runner-test/services"}, _, _, opts) do
      params = opts[:params]
      page1_items = [build_service("foo", "stream-runner-test")]
      page2_items = [build_service("bar", "stream-runner-test")]
      page3_items = [build_service("qux", "stream-runner-test")]

      body =
        case params do
          [limit: 10, continue: nil] ->
            build_list(page1_items, "start")

          [limit: 10, continue: "start"] ->
            build_list(page2_items, "end")

          [limit: 10, continue: "end"] ->
            build_list(page3_items)
        end

      {:ok, body}
    end
  end

  setup do
    DynamicHTTPProvider.register(self(), __MODULE__.HTTPMock)
    {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
    {:ok, %{conn: conn}}
  end

  describe "run/3" do
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

    test "returns an error if operation not supported", %{conn: conn} do
      op = K8s.Client.delete_all("v1", "pods")
      assert {:error, error} = K8s.Client.stream(conn, op)

      assert error.message =~
               "Only [:list, :list_all_namespaces, :watch, :watch_all_namespaces, :connect] operations can be streamed."
    end
  end
end
