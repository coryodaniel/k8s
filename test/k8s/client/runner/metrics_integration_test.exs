defmodule K8s.Client.Runner.MetricsIntegrationTest do
  use ExUnit.Case, async: false
  import K8s.Test.IntegrationHelper

  setup_all do
    [conn: conn()]
  end

  describe "metrics for pods and nodes" do
    test "fetch metrics for nodes", %{conn: conn} do
      operation = K8s.Client.metrics("metrics.k8s.io/v1beta1", "nodes")

      {:ok, metrics_result} = K8s.Client.run(conn, operation)

      assert Enum.all?(metrics_result["items"], fn item ->
        item["usage"]["cpu"] != nil
        item["usage"]["memory"] != nil
      end)
    end

    test "fetch metrics for pods", %{conn: conn} do
      operation = K8s.Client.metrics("metrics.k8s.io/v1beta1", :pods, namespace: "kube-system")
      {:ok, metrics_result} = K8s.Client.run(conn, operation)

      assert Enum.count(metrics_result["items"]) > 0, "Expected to find metrics for pods in kube-system namespace"
      assert Enum.all?(metrics_result["items"], fn item ->
        Enum.all?(item["containers"], fn container ->
          container["usage"]["cpu"] != nil and container["usage"]["memory"] != nil
        end)
      end), "Expected to find CPU and memory usage for all containers in pods in kube-system namespace"
    end

  end
end
