defmodule K8s.Client.Runner.WatchIntegrationTest do
  use ExUnit.Case, async: false
  import K8s.Test.IntegrationHelper

  setup do
    test_id = :rand.uniform(10_000)
    labels = %{"k8s-ex-watch-test" => "#{test_id}", "k8s-ex" => "true"}
    conn = conn()

    on_exit(fn ->
      delete_pod =
        K8s.Client.delete(%{
          "apiVersion" => "v1",
          "kind" => "Pod",
          "metadata" => %{"name" => "watch-nginx-#{test_id}"}
        })

      K8s.Client.run(conn, delete_pod)
    end)

    {:ok, %{conn: conn, test_id: test_id, labels: labels}}
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

    pod1 = pod("watch-nginx-#{test_id}", labels)
    {:ok, pod1} = K8s.Client.run(conn, pod1)

    assert_receive %HTTPoison.AsyncStatus{code: 200}
    assert_receive %HTTPoison.AsyncHeaders{}
    assert_receive %HTTPoison.AsyncChunk{chunk: chunk}
    assert String.match?(chunk, ~r/ADDED/)

    K8s.Client.run(conn, K8s.Client.delete(pod1))
  end

  @tag integration: true
  test "watches and streams a resource", %{conn: conn, labels: labels, test_id: test_id} do
    selector = K8s.Selector.label(labels)
    operation = K8s.Client.list("v1", "Pod", namespace: "default")
    operation = K8s.Operation.put_label_selector(operation, selector)
    event_stream = K8s.Client.Runner.Watch.stream(conn, operation)

    Task.async(fn ->
      # give watcher time to initialize in order to not miss first event
      :timer.sleep(500)

      pod = build_pod("watch-nginx-#{test_id}", labels)

      op = K8s.Client.create(pod)
      {:ok, _} = K8s.Client.run(conn, op)

      op =
        pod
        |> put_in(["metadata", Access.key("annotations", %{}), "some"], "value")
        |> Map.delete("spec")
        |> K8s.Client.patch()

      {:ok, _} = K8s.Client.run(conn, op)

      op = K8s.Client.delete(pod)
      {:ok, _} = K8s.Client.run(conn, op)
    end)

    [add_event | other_events] =
      event_stream
      |> Stream.take_while(&(&1["type"] != "DELETED"))
      |> Enum.to_list()

    assert "ADDED" == add_event["type"]
    assert is_nil(get_in(add_event, ~w(object metadata annotations some)))
    refute Enum.empty?(other_events)
    assert true == Enum.all?(other_events, &(&1["type"] == "MODIFIED"))
  end
end
