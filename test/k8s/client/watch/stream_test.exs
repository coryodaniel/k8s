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
    import K8s.Test.HTTPHelper

    def request(:get, "https://localhost:6443/api/v1/namespaces", _body, _headers, opts) do
      case get_in(opts, [:params, :watch]) do
        true ->
          assert "10" == get_in(opts, [:params, :resourceVersion])
          pid = Keyword.fetch!(opts, :stream_to)

          send_chunk(pid, %{
            "type" => "ADDED",
            "object" => %{
              "apiVersion" => "v1",
              "kind" => "Namespace",
              "metadata" => %{"resourceVersion" => "11"}
            }
          })

          send_chunk(pid, %{
            "type" => "MODIFIED",
            "object" => %{
              "apiVersion" => "v1",
              "kind" => "Namespace",
              "metadata" => %{"resourceVersion" => "12"}
            }
          })

          #  ignored
          send_chunk(pid, %{
            "type" => "MODIFIED",
            "object" => %{
              "apiVersion" => "v1",
              "kind" => "Namespace",
              "metadata" => %{"resourceVersion" => "12"}
            }
          })

          send_chunk(pid, %{
            "type" => "DELETED",
            "object" => %{
              "apiVersion" => "v1",
              "kind" => "Namespace",
              "metadata" => %{"resourceVersion" => "13"}
            }
          })

          {:ok, %HTTPoison.AsyncResponse{id: make_ref()}}

        nil ->
          render(%{"metadata" => %{"resourceVersion" => "10"}})
      end
    end

    def request(:get, "https://localhost:6443/api/v1/services", _body, _headers, opts) do
      case get_in(opts, [:params, :watch]) do
        true ->
          assert "10" == get_in(opts, [:params, :resourceVersion])
          pid = Keyword.fetch!(opts, :stream_to)
          send(pid, %HTTPoison.AsyncEnd{})

          send_chunk(pid, %{
            "type" => "ADDED",
            "object" => %{
              "apiVersion" => "v1",
              "kind" => "Service",
              "metadata" => %{"resourceVersion" => "11"}
            }
          })

          {:ok, %HTTPoison.AsyncResponse{id: make_ref()}}

        nil ->
          render(%{"metadata" => %{"resourceVersion" => "10"}})
      end
    end

    def request(:get, "https://localhost:6443/api/v1/pods", _body, _headers, opts) do
      case get_in(opts, [:params, :watch]) do
        true ->
          assert "10" == get_in(opts, [:params, :resourceVersion])
          pid = Keyword.fetch!(opts, :stream_to)
          send(pid, %HTTPoison.AsyncStatus{code: 410})

          send_chunk(pid, %{
            "type" => "ADDED",
            "object" => %{
              "apiVersion" => "v1",
              "kind" => "Pod",
              "metadata" => %{"resourceVersion" => "11"}
            }
          })

          {:ok, %HTTPoison.AsyncResponse{id: make_ref()}}

        nil ->
          render(%{"metadata" => %{"resourceVersion" => "10"}})
      end
    end

    def request(:get, "https://localhost:6443/apis/apps/v1/daemonsets", _body, _headers, opts) do
      case get_in(opts, [:params, :watch]) do
        true ->
          assert "10" == get_in(opts, [:params, :resourceVersion])
          pid = Keyword.fetch!(opts, :stream_to)
          send(pid, %HTTPoison.AsyncStatus{code: 500})

          send_chunk(pid, %{
            "type" => "ADDED",
            "object" => %{
              "apiVersion" => "apps/v1",
              "kind" => "DaemonSet",
              "metadata" => %{"resourceVersion" => "11"}
            }
          })

          {:ok, %HTTPoison.AsyncResponse{id: make_ref()}}

        nil ->
          render(%{"metadata" => %{"resourceVersion" => "10"}})
      end
    end

    def request(:get, "https://localhost:6443/apis/apps/v1/deployments", _body, _headers, opts) do
      case get_in(opts, [:params, :watch]) do
        true ->
          rv = get_in(opts, [:params, :resourceVersion])
          assert rv in ["10", "11"]
          pid = Keyword.fetch!(opts, :stream_to)

          case rv do
            "10" ->
              send_chunk(pid, %{
                "type" => "ADDED",
                "object" => %{
                  "apiVersion" => "apps/v1",
                  "kind" => "Deployment",
                  "metadata" => %{"resourceVersion" => "11"}
                }
              })

              send(pid, %HTTPoison.Error{reason: {:closed, :timeout}})

            "11" ->
              send_chunk(pid, %{
                "type" => "DELETED",
                "object" => %{
                  "apiVersion" => "apps/v1",
                  "kind" => "Deployment",
                  "metadata" => %{"resourceVersion" => "12"}
                }
              })
          end

          {:ok, %HTTPoison.AsyncResponse{id: make_ref()}}

        nil ->
          render(%{"metadata" => %{"resourceVersion" => "10"}})
      end
    end

    def request(_method, _url, _body, _headers, _opts) do
      Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
      {:error, %HTTPoison.Error{reason: "request not mocked"}}
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

      events =
        MUT.resource(conn, operation, [])
        |> Enum.take(3)
        |> Enum.to_list()

      assert ["ADDED", "MODIFIED", "DELETED"] == Enum.map(events, & &1["type"])
    end

    @tag timeout: 1_000
    test "Resumes the stream when AsyncEnd is sent", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("v1", "Service")

        [event1 | [event2 | _]] =
          MUT.resource(conn, operation, [])
          |> Stream.take(2)
          |> Enum.to_list()

        assert "ADDED" == event1["type"]
        assert "ADDED" == event2["type"]
      end

      assert capture_log(test) =~ "AsyncEnd received"
    end

    @tag timeout: 1_000
    test "Resumes the stream when 410 Gone is sent", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("v1", "Pod")

        [event1 | [event2 | _]] =
          MUT.resource(conn, operation, [])
          |> Stream.take(2)
          |> Enum.to_list()

        assert "ADDED" == event1["type"]
        assert "ADDED" == event2["type"]
      end

      assert capture_log(test) =~ "410 Gone received"
    end

    @tag timeout: 1_000
    test "Aborts the stream when any other error is sent", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("apps/v1", "DaemonSet")

        events =
          MUT.resource(conn, operation, [])
          |> Enum.to_list()

        assert [] == events
      end

      assert capture_log(test) =~ "Erronous async status received"
    end

    @tag timeout: 1_000
    test "Resumes the stream when request times out", %{conn: conn} do
      test = fn ->
        operation = K8s.Client.list("apps/v1", "Deployment")

        [event1 | [event2 | _]] =
          MUT.resource(conn, operation, [])
          |> Stream.take(2)
          |> Enum.to_list()

        assert "ADDED" == event1["type"]
        assert "DELETED" == event2["type"]
      end

      assert capture_log(test) =~ "resuming the watch"
    end
  end
end
