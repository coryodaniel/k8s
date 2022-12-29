defmodule K8s.Client.Runner.StreamIntegrationTest do
  use ExUnit.Case, async: true
  import K8s.Test.IntegrationHelper

  setup_all do
    conn = conn()

    on_exit(fn ->
      K8s.Client.delete(%{
        "apiVersion" => "v1",
        "kind" => "Pod"
      })
      |> K8s.Selector.label({"k8s-ex-test", "stream"})
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()
    end)

    [conn: conn]
  end

  setup do
    test_id = :rand.uniform(10_000)
    labels = %{"k8s-ex-stream-test" => "#{test_id}", "k8s-ex-test" => "stream"}
    {:ok, %{test_id: test_id, labels: labels}}
  end

  @spec pod(binary, map) :: K8s.Operation.t()
  defp pod(name, labels) do
    name
    |> build_pod(labels)
    |> K8s.Client.create()
  end

  @tag :integration
  test "returns a list of resources", %{conn: conn, labels: labels, test_id: test_id} do
    # Note: stream_test.exs tests functionality of creating the stream
    # This test is a simple integration test against a real cluster
    pod1 = pod("stream-nginx-#{test_id}-1", labels)
    {:ok, to_delete_1} = K8s.Client.run(conn, pod1)

    pod2 = pod("stream-nginx-#{test_id}-2", labels)
    {:ok, to_delete_2} = K8s.Client.run(conn, pod2)

    assert {:ok, stream} =
             K8s.Client.list("v1", "Pod", namespace: "default")
             |> K8s.Operation.put_selector(K8s.Selector.label(labels))
             |> K8s.Client.put_conn(conn)
             |> K8s.Client.stream()

    resources =
      stream
      |> Stream.take(2)
      |> Stream.map(&K8s.Resource.name/1)
      |> Enum.sort()

    K8s.Client.run(conn, K8s.Client.delete(to_delete_1))
    K8s.Client.run(conn, K8s.Client.delete(to_delete_2))

    assert resources == ["stream-nginx-#{test_id}-1", "stream-nginx-#{test_id}-2"]
  end

  @tag :integration
  @tag :websocket
  test "returns error if connection fails", %{conn: conn} do
    result =
      K8s.Client.connect(
        "v1",
        "pods/exec",
        [
          namespace: "default",
          name: "does-not-exist"
        ],
        command: ["/bin/sh"],
        tty: false
      )
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.stream()

    assert {:error, error} = result
    assert error.message =~ "404"
  end
end
