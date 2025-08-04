defmodule K8s.Client.Runner.MetricsIntegrationTest do
  use ExUnit.Case, async: false
  import K8s.Test.IntegrationHelper

  setup_all do
    conn = conn()

    on_exit(fn ->
      K8s.Client.delete_all("v1", "Pod", namespace: "default")
      |> K8s.Selector.label({"k8s-ex-test", "metrics"})
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()
    end)

    [conn: conn]
  end

  setup do
    test_id = :rand.uniform(10_000)
    labels = %{"k8s-ex-metrics-test" => "#{test_id}", "k8s-ex-test" => "metrics"}

    {:ok, %{test_id: test_id, labels: labels}}
  end

  describe "metrics for pods and nodes" do
    setup %{test_id: test_id} do

      [
        resource_name: "metrics-#{test_id}"
      ]
    end

    test "fetch metrics for nodes", %{conn: conn} do
      operation = K8s.Client.metrics("v1", "Node")

      {:ok, metrics_result} = K8s.Client.run(conn, operation)

      assert Enum.all?(metrics_result["items"], fn item ->
        item["status"]["allocatable"]["cpu"] != nil
        item["status"]["allocatable"]["memory"] != nil
        item["status"]["allocatable"]["ephemeral-storage"] != nil
        item["status"]["allocatable"]["pods"] != nil
        item["status"]["capacity"]["cpu"] != nil
        item["status"]["capacity"]["memory"] != nil
        item["status"]["capacity"]["ephemeral-storage"] != nil
        item["status"]["capacity"]["pods"] != nil
      end)
    end

    test "fetch metrics for pods", %{conn: conn,
      test_id: test_id,
      labels: labels
    } do
      selector = K8s.Selector.label(labels)
      operation = K8s.Client.metrics("v1", "Pod", namespace: "default")
      operation = K8s.Operation.put_selector(operation, selector)

      pod = build_pod("k8s-metrics-1-#{test_id}", labels)

      assert {:ok, _pod} =
               pod
               |> K8s.Client.create()
               |> K8s.Client.put_conn(conn)
               |> K8s.Client.run()

      pod = build_pod("k8s-metrics-2-#{test_id}", labels)

      assert {:ok, _pod} =
               pod
               |> K8s.Client.create()
               |> K8s.Client.put_conn(conn)
               |> K8s.Client.run()

      {:ok, metrics_result} = K8s.Client.run(conn, operation)

      assert Enum.count(metrics_result["items"]) == 2
      assert Enum.all?(metrics_result["items"], fn item ->
        item["metadata"]["name"] in ["k8s-metrics-1-#{test_id}", "k8s-metrics-2-#{test_id}"]
        item["status"]["phase"] != nil
      end)
    end

  end
end
