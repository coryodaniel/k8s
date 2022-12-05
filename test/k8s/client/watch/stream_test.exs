defmodule K8s.Client.Runner.Watch.StreamTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true

  alias K8s.Client.Runner.Watch.Stream, as: MUT
  alias K8s.Client.DynamicHTTPProvider

  import ExUnit.CaptureLog

  require Logger

  defmodule HTTPMock do
    @moduledoc """
    Mocks requests. Since each test waches different resources (namespace, service, pod,...), each request block
    in this module matches up with (i.e. handles) exactly one test.
    """
    alias K8s.Client.HTTPTestHelper

    def request(
          :get,
          "https://localhost:6443/api/v1/namespaces",
          _body,
          _headers,
          _opts
        ) do
      {:ok, %{"metadata" => %{"resourceVersion" => "10"}}}
    end

    def request(
          :get,
          "https://localhost:6443/api/v1/pods",
          _body,
          _headers,
          _opts
        ) do
      {:ok, %{"metadata" => %{"resourceVersion" => "10"}}}
    end

    def request(
          :get,
          "https://localhost:6443/apis/apps/v1/daemonsets",
          _body,
          _headers,
          _opts
        ) do
      {:ok, %{"metadata" => %{"resourceVersion" => "10"}}}
    end

    def request(
          :get,
          "https://localhost:6443/apis/apps/v1/deployments",
          _body,
          _headers,
          _opts
        ) do
      {:ok, %{"metadata" => %{"resourceVersion" => "10"}}}
    end

    def request(
          :get,
          "https://localhost:6443/apis/apps/v1/statefulsets",
          _body,
          _headers,
          _opts
        ) do
      {:ok, %{"metadata" => %{"resourceVersion" => "10"}}}
    end

    def request(
          :get,
          "https://localhost:6443/api/v1/services",
          _body,
          _headers,
          _opts
        ) do
      {:ok, %{"metadata" => %{"resourceVersion" => "10"}}}
    end

    def request(
          :get,
          "https://localhost:6443/apis/apps/v1/replicasets",
          _body,
          _headers,
          _opts
        ) do
      {:ok, %{"metadata" => %{"resourceVersion" => "10"}}}
    end

    def request(
          :get,
          "https://localhost:6443/api/v1/configmaps",
          _body,
          _headers,
          _opts
        ) do
      {:ok, %{"metadata" => %{"resourceVersion" => "10"}}}
    end

    def stream(
          :get,
          "https://localhost:6443/api/v1/namespaces",
          _body,
          _headers,
          opts
        ) do
      assert "10" == get_in(opts, [:params, :resourceVersion])

      stream = [
        HTTPTestHelper.stream_object(%{
          "type" => "ADDED",
          "object" => %{
            "apiVersion" => "v1",
            "kind" => "Namespace",
            "metadata" => %{"resourceVersion" => "11"}
          }
        }),

        # Split object chunks
        {:data, ~s({"object":{"apiVersion":")},
        {:data, ~s(v1","kind":"Name)},
        {:data, ~s(space","metadata":{"resourceVer)},
        {:data, ~s(sion":"12"}},"type":"MODIFIED"})},
        {:data, "\n"},
        # 2 objects in one junk - but first one is ignored because same resourceVersion as above:
        {:data,
         """
         {"object":{"apiVersion":"v1","kind":"Namespace","metadata":{"resourceVersion":"12"}},"type":"MODIFIED"}
         {"object":{"apiVersion":"v1","kind":"Namespace","metadata":{"resourceVersion":"13"}},"type":"DELETED"}
         """}
      ]

      {:ok, stream}
    end

    def stream(
          :get,
          "https://localhost:6443/api/v1/pods",
          _body,
          _headers,
          opts
        ) do
      stream =
        case get_in(opts, [:params, :resourceVersion]) do
          "10" ->
            [
              HTTPTestHelper.stream_object(%{
                "type" => "ADDED",
                "object" => %{
                  "apiVersion" => "v1",
                  "kind" => "Pod",
                  "metadata" => %{"resourceVersion" => "11"}
                }
              }),
              {:status, 410}
            ]

          "11" ->
            [
              HTTPTestHelper.stream_object(%{
                "type" => "DELETED",
                "object" => %{
                  "apiVersion" => "v1",
                  "kind" => "Pod",
                  "metadata" => %{"resourceVersion" => "12"}
                }
              })
            ]
        end

      {:ok, stream}
    end

    def stream(
          :get,
          "https://localhost:6443/apis/apps/v1/daemonsets",
          _body,
          _headers,
          opts
        ) do
      assert "10" == get_in(opts, [:params, :resourceVersion])

      stream = [
        {:status, 500},
        HTTPTestHelper.stream_object(%{
          "type" => "ADDED",
          "object" => %{
            "apiVersion" => "v1",
            "kind" => "DaemonSet",
            "metadata" => %{"resourceVersion" => "11"}
          }
        })
      ]

      {:ok, stream}
    end

    def stream(
          :get,
          "https://localhost:6443/apis/apps/v1/deployments",
          _body,
          _headers,
          opts
        ) do
      rv = get_in(opts, [:params, :resourceVersion])
      assert rv in ["10", "11"]

      stream =
        case rv do
          "10" ->
            [
              HTTPTestHelper.stream_object(%{
                "type" => "ADDED",
                "object" => %{
                  "apiVersion" => "apps/v1",
                  "kind" => "Deployment",
                  "metadata" => %{"resourceVersion" => "11"}
                }
              }),
              {:error, {:closed, :timeout}}
            ]

          "11" ->
            [
              HTTPTestHelper.stream_object(%{
                "type" => "DELETED",
                "object" => %{
                  "apiVersion" => "apps/v1",
                  "kind" => "Deployment",
                  "metadata" => %{"resourceVersion" => "12"}
                }
              })
            ]
        end

      {:ok, stream}
    end

    def stream(
          :get,
          "https://localhost:6443/apis/apps/v1/statefulsets",
          _body,
          _headers,
          opts
        ) do
      assert "10" == get_in(opts, [:params, :resourceVersion])

      stream = [
        HTTPTestHelper.stream_object(%{
          "type" => "ADDED",
          "object" => %{
            "apiVersion" => "apps/v1",
            "kind" => "StatefulSet",
            "metadata" => %{"resourceVersion" => "11"}
          }
        }),
        {:data, "this-is-not-json\n"},
        HTTPTestHelper.stream_object(%{
          "type" => "DELETED",
          "object" => %{
            "apiVersion" => "apps/v1",
            "kind" => "StatefulSet",
            "metadata" => %{"resourceVersion" => "12"}
          }
        })
      ]

      {:ok, stream}
    end

    def stream(
          :get,
          "https://localhost:6443/apis/apps/v1/replicasets",
          _body,
          _headers,
          opts
        ) do
      assert get_in(opts, [:params, :resourceVersion]) in ["10", "12"]

      stream = [
        HTTPTestHelper.stream_object(%{
          "type" => "ADDED",
          "object" => %{
            "apiVersion" => "apps/v1",
            "kind" => "ReplicaSet",
            "metadata" => %{"resourceVersion" => "11"}
          }
        }),
        HTTPTestHelper.stream_object(%{
          "type" => "ERROR",
          "object" => %{
            "message" => "Some error"
          }
        }),
        HTTPTestHelper.stream_object(%{
          "type" => "DELETED",
          "object" => %{
            "apiVersion" => "apps/v1",
            "kind" => "ReplicaSet",
            "metadata" => %{"resourceVersion" => "12"}
          }
        })
      ]

      {:ok, stream}
    end

    def stream(
          :get,
          "https://localhost:6443/api/v1/services",
          _body,
          _headers,
          opts
        ) do
      stream =
        case get_in(opts, [:params, :resourceVersion]) do
          "10" ->
            [
              {:status, 200},
              HTTPTestHelper.stream_object(%{
                "type" => "BOOKMARK",
                "object" => %{
                  "apiVersion" => "v1",
                  "kind" => "Service",
                  "metadata" => %{"resourceVersion" => "11"}
                }
              })
            ]

          "11" ->
            [
              {:status, 200},
              HTTPTestHelper.stream_object(%{
                "type" => "ADDED",
                "object" => %{
                  "apiVersion" => "v1",
                  "kind" => "Service",
                  "metadata" => %{"resourceVersion" => "12"}
                }
              })
            ]
        end

      {:ok, stream}
    end

    def stream(
          :get,
          "https://localhost:6443/api/v1/configmaps",
          _body,
          _headers,
          opts
        ) do
      stream =
        case get_in(opts, [:params, :resourceVersion]) do
          "10" ->
            [
              {:status, 200},
              HTTPTestHelper.stream_object(%{
                "type" => "ADDED",
                "object" => %{
                  "apiVersion" => "v1",
                  "kind" => "Pod",
                  "metadata" => %{"resourceVersion" => "11"}
                }
              }),
              HTTPTestHelper.stream_object(%{
                "type" => "ADDED",
                "object" => %{
                  "apiVersion" => "v1",
                  "kind" => "Pod",
                  "metadata" => %{"resourceVersion" => "12"}
                }
              })
            ]

          "12" ->
            [
              {:status, 200},
              HTTPTestHelper.stream_object(%{
                "type" => "ERROR",
                "object" => %{
                  "apiVersion" => "v1",
                  "code" => 410,
                  "kind" => "Status",
                  "message" => "too old resource version: 11 (12)",
                  "metadata" => %{},
                  "reason" => "Expired",
                  "status" => "Failure"
                }
              })
            ]
        end

      {:ok, stream}
    end

    def stream(_method, _url, _body, _headers, _opts, _stream_to_pid) do
      Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
      {:error, %K8s.Client.HTTPError{message: "request not mocked"}}
    end
  end

  setup do
    DynamicHTTPProvider.register(self(), __MODULE__.HTTPMock)
    {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
    {:ok, %{conn: conn}}
  end

  describe "resource/3" do
    @tag timeout: 1_000
    test "Watches a list operation and returns the correct stream", %{conn: conn} do
      operation = K8s.Client.list("v1", "Namespace")

      {:ok, stream} = MUT.resource(conn, operation, [])

      events =
        stream
        |> Enum.take(3)
        |> Enum.to_list()

      assert ["ADDED", "MODIFIED", "DELETED"] == Enum.map(events, & &1["type"])
    end

    @tag timeout: 1_000
    test "Resumes the stream when 410 Gone is sent", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("v1", "Pod")

        {:ok, stream} = MUT.resource(conn, operation, [])

        events =
          stream
          |> Stream.take(4)
          |> Enum.to_list()

        #  goes on forever, but we only took 4
        assert ["ADDED", "ADDED", "ADDED", "ADDED"] == Enum.map(events, & &1["type"])
      end

      assert capture_log(test) =~ "410 Gone received"
    end

    @tag timeout: 1_000
    test "Resumes the stream when 410 Gone is sent as chunk", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("v1", "ConfigMap")

        {:ok, stream} = MUT.resource(conn, operation, [])

        events =
          stream
          |> Stream.take(4)
          |> Enum.to_list()

        #  goes on forever, but we only took 4
        assert ["ADDED", "ADDED", "ADDED", "ADDED"] == Enum.map(events, & &1["type"])

        assert ["11", "12", "11", "12"] ==
                 Enum.map(events, & &1["object"]["metadata"]["resourceVersion"])
      end

      assert capture_log(test) =~ "too old resource version"
    end

    @tag timeout: 1_000
    test "Updates the resource version when BOOKMARK event is received", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("v1", "Service")

        {:ok, stream} = MUT.resource(conn, operation, [])

        events =
          stream
          |> Stream.take(1)
          |> Enum.to_list()

        #  goes on forever, but we only took 4
        assert ["ADDED"] == Enum.map(events, & &1["type"])
      end

      assert capture_log(test) =~ "Bookmark received"
    end

    @tag timeout: 1_000
    test "Aborts the stream when any other error is sent", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("apps/v1", "DaemonSet")

        {:ok, stream} = MUT.resource(conn, operation, [])
        events = Enum.to_list(stream)

        assert [] == events
      end

      assert capture_log(test) =~ "Erronous async status 500 received"
    end

    @tag timeout: 1_000
    test "Resumes the stream when request times out", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("apps/v1", "Deployment")

        {:ok, stream} = MUT.resource(conn, operation, [])

        [event1 | [event2 | _]] =
          stream
          |> Stream.take(2)
          |> Enum.to_list()

        assert "ADDED" == event1["type"]
        assert "DELETED" == event2["type"]
      end

      assert capture_log(test) =~ "resuming the watch"
    end

    @tag timeout: 1_000
    test "Skips malformed JSON events", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("apps/v1", "StatefulSet")

        {:ok, stream} = MUT.resource(conn, operation, [])

        [event1 | [event2 | _]] =
          stream
          |> Stream.take(2)
          |> Enum.to_list()

        assert "ADDED" == event1["type"]
        assert "DELETED" == event2["type"]
      end

      assert capture_log(test) =~ "Could not decode JSON"
    end

    @tag timeout: 1_000
    test "Resumes the stream when error message is sent", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("apps/v1", "ReplicaSet")

        {:ok, stream} = MUT.resource(conn, operation, [])

        events =
          stream
          |> Stream.take(4)
          |> Enum.to_list()

        assert ["ADDED", "DELETED", "ADDED", "DELETED"] == Enum.map(events, & &1["type"])
      end

      assert capture_log(test) =~ "Erronous event received"
    end
  end
end
