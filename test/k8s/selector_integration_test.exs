defmodule K8s.SelectorIntegrationTest do
  use ExUnit.Case, async: true

  alias K8s.Selector, as: MUT
  alias K8s.Test.IntegrationHelper

  setup_all do
    conn = IntegrationHelper.conn()

    cm =
      IntegrationHelper.build_configmap("selector-integration-test", %{"foo" => "bar"},
        labels: %{
          "env" => "test",
          "app" => "nginx",
          "tier" => "backend"
        }
      )

    K8s.Client.run(conn, K8s.Client.apply(cm))

    on_exit(fn ->
      K8s.Client.run(conn, K8s.Client.delete(cm))
    end)

    [conn: conn]
  end

  describe "labels" do
    test "Finds resource via label selectors", %{conn: conn} do
      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label({"tier", "backend"})

      {:ok, %{"items" => [resource]}} = K8s.Client.run(conn, op)

      assert "selector-integration-test" == resource["metadata"]["name"]

      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label({"tier", "frontend"})

      {:ok, %{"items" => []}} = K8s.Client.run(conn, op)
    end

    test "Finds resource via label_not selectors", %{conn: conn} do
      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label_not({"tier", "frontend"})

      {:ok, %{"items" => [resource]}} = K8s.Client.run(conn, op)

      assert "selector-integration-test" == resource["metadata"]["name"]

      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label_not({"tier", "backend"})

      {:ok, %{"items" => []}} = K8s.Client.run(conn, op)
    end

    test "Finds resource via label_does_not_exist expression", %{conn: conn} do
      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label_does_not_exist("tier")

      {:ok, %{"items" => []}} = K8s.Client.run(conn, op)

      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label_does_not_exist("foo")

      {:ok, %{"items" => [resource]}} = K8s.Client.run(conn, op)
      assert "selector-integration-test" == resource["metadata"]["name"]
    end

    test "Finds resource via label_exists expression", %{conn: conn} do
      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label_exists("foo")

      {:ok, %{"items" => []}} = K8s.Client.run(conn, op)

      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label_exists("tier")

      {:ok, %{"items" => [resource]}} = K8s.Client.run(conn, op)
      assert "selector-integration-test" == resource["metadata"]["name"]
    end

    test "Finds resource via label_in and label_not_in expression", %{conn: conn} do
      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label_not_in({"tier", ["fronten", "backend"]})

      {:ok, %{"items" => []}} = K8s.Client.run(conn, op)

      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label_in({"tier", ["fronten", "backend"]})

      {:ok, %{"items" => [resource]}} = K8s.Client.run(conn, op)
      assert "selector-integration-test" == resource["metadata"]["name"]
    end
  end

  describe "fields" do
    test "Finds resource via field selectors", %{conn: conn} do
      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label({"tier", "backend"})
        |> MUT.field({"metadata.namespace", "default"})

      {:ok, %{"items" => [resource]}} = K8s.Client.run(conn, op)

      assert "selector-integration-test" == resource["metadata"]["name"]

      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label({"tier", "backend"})
        |> MUT.field({"metadata.namespace", "bar"})

      {:ok, %{"items" => []}} = K8s.Client.run(conn, op)
    end

    test "Finds resource via field_not selectors", %{conn: conn} do
      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label({"tier", "backend"})
        |> MUT.field_not({"metadata.namespace", "bar"})

      {:ok, %{"items" => [resource]}} = K8s.Client.run(conn, op)

      assert "selector-integration-test" == resource["metadata"]["name"]

      op =
        K8s.Client.list("v1", "ConfigMap", namespace: "default")
        |> MUT.label({"env", "test"})
        |> MUT.label({"app", "nginx"})
        |> MUT.label({"tier", "backend"})
        |> MUT.field_not({"metadata.namespace", "default"})

      {:ok, %{"items" => []}} = K8s.Client.run(conn, op)
    end
  end
end
