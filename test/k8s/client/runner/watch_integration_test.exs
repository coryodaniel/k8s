defmodule K8s.Client.Runner.WatchIntegrationTest do
  use ExUnit.Case, async: true
  import K8s.Test.IntegrationHelper

  setup do
    test_id = :rand.uniform(10_000)
    labels = %{"k8s-ex-watch-test" => "#{test_id}", "k8s-ex" => "true"}
    {:ok, %{conn: conn(), test_id: test_id, labels: labels}}
  end

  @spec pod(binary, map) :: K8s.Operation.t()
  defp pod(name, labels) do
    name
    |> build_pod(labels)
    |> K8s.Client.create()
  end

  @tag integration: true
  test "watches an operation", %{conn: conn, labels: labels, test_id: test_id} do
    selector = K8s.Selector.label(labels)
    operation = K8s.Client.list("v1", "Pod", namespace: "default")
    operation = K8s.Operation.put_label_selector(operation, selector)

    this = self()
    {:ok, _reference} = K8s.Client.Runner.Watch.run(conn, operation, "0", stream_to: this)

    pod1 = pod("watch-nginx-#{test_id}-1", labels)
    {:ok, _} = K8s.Client.run(conn, pod1)

    assert_receive %HTTPoison.AsyncStatus{code: 200}
    assert_receive %HTTPoison.AsyncHeaders{}
    assert_receive %HTTPoison.AsyncChunk{chunk: chunk}
    assert String.match?(chunk, ~r/ADDED/)
  end
end
