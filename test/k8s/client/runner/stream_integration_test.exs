defmodule K8s.Client.Runner.StreamIntegrationTest do
  use ExUnit.Case, async: true
  import K8s.Test.IntegrationHelper

  setup do
    test_id = :rand.uniform(10_000)
    labels = %{"k8s-ex-stream-test" => "#{test_id}", "k8s-ex" => "true"}
    {:ok, %{conn: conn(), test_id: test_id, labels: labels}}
  end

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
    {:ok, _} = K8s.Client.run(conn, pod1)

    pod2 = pod("stream-nginx-#{test_id}-2", labels)
    {:ok, _} = K8s.Client.run(conn, pod2)

    selector = K8s.Selector.label(labels)
    operation = K8s.Client.list("v1", "Pod", namespace: "default")
    operation = K8s.Operation.put_label_selector(operation, selector)
    assert {:ok, stream} = K8s.Client.Runner.Stream.run(conn, operation)

    resources =
      stream
      |> Enum.take(2)
      |> Enum.reduce([], fn resource, agg -> [K8s.Resource.name(resource) | agg] end)
      |> Enum.sort()

    assert resources == ["stream-nginx-#{test_id}-1", "stream-nginx-#{test_id}-2"]
  end
end
