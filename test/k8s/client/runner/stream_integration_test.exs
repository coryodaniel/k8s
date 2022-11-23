defmodule K8s.Client.Runner.StreamIntegrationTest do
  use ExUnit.Case, async: true
  import K8s.Test.IntegrationHelper

  setup do
    test_id = :rand.uniform(10_000)
    labels = %{"k8s-ex-stream-test" => "#{test_id}", "k8s-ex" => "true"}
    {:ok, %{conn: conn(), test_id: test_id, labels: labels}}
  end

  @spec pod(binary, map) :: K8s.Operation.t()
  defp pod(name, labels) do
    name
    |> build_pod(labels)
    |> K8s.Client.create()
  end

  @tag integration: true
  test "returns a list of resources", %{conn: conn, labels: labels, test_id: test_id} do
    # Note: stream_test.exs tests functionality of creating the stream
    # This test is a simple integration test against a real cluster
    pod1 = pod("stream-nginx-#{test_id}-1", labels)
    {:ok, to_delete_1} = K8s.Client.run(conn, pod1)

    pod2 = pod("stream-nginx-#{test_id}-2", labels)
    {:ok, to_delete_2} = K8s.Client.run(conn, pod2)

    selector = K8s.Selector.label(labels)
    operation = K8s.Client.list("v1", "Pod", namespace: "default")
    operation = K8s.Operation.put_selector(operation, selector)
    assert {:ok, stream} = K8s.Client.Runner.Stream.run(conn, operation)

    resources =
      stream
      |> Enum.take(2)
      |> Enum.reduce([], fn resource, agg -> [K8s.Resource.name(resource) | agg] end)
      |> Enum.sort()

    K8s.Client.run(conn, K8s.Client.delete(to_delete_1))
    K8s.Client.run(conn, K8s.Client.delete(to_delete_2))

    assert resources == ["stream-nginx-#{test_id}-1", "stream-nginx-#{test_id}-2"]
  end

  @tag integration: true
  test "running a command in a container", %{conn: conn} do
    connect_op =
      K8s.Client.connect("v1", "pods/exec", namespace: "default", name: "nginx-76d6c9b8c-sq56w")

    operation =
      K8s.Operation.put_query_param(connect_op,
        command: ["/bin/sh", "-c", "date"],
        stdin: true,
        stdout: true,
        stderr: true,
        tty: true
      )

    assert {:ok, stream} = K8s.Client.Runner.Stream.run(conn, operation)
    assert Enum.take(stream, 1) != []
  end
end
