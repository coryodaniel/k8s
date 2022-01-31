defmodule K8s.Client.Runner.BaseIntegrationTest do
  use ExUnit.Case, async: true
  import K8s.Test.IntegrationHelper

  setup do
    test_id = :rand.uniform(10_000)
    {:ok, %{conn: conn(), test_id: test_id}}
  end

  describe "cluster scoped resources" do
    @tag integration: true
    test "creating a resource", %{conn: conn, test_id: test_id} do
      namespace = %{
        "apiVersion" => "v1",
        "kind" => "Namespace",
        "metadata" => %{"name" => "k8s-ex-#{test_id}"}
      }

      operation = K8s.Client.create(namespace)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result

      operation = K8s.Client.delete(namespace)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result
    end

    @tag integration: true
    test "getting a resource", %{conn: conn} do
      operation = K8s.Client.get("v1", "Namespace", name: "default")
      result = K8s.Client.run(conn, operation)

      assert {:ok, %{"apiVersion" => "v1", "kind" => "Namespace"}} = result
    end

    @tag integration: true
    test "listing resources", %{conn: conn} do
      operation = K8s.Client.list("v1", "Namespace")

      assert {:ok,
              %{
                "items" => namespaces,
                "apiVersion" => "v1",
                "kind" => "NamespaceList"
              }} = K8s.Client.run(conn, operation)

      namespace_names = Enum.map(namespaces, fn ns -> get_in(ns, ["metadata", "name"]) end)
      assert Enum.member?(namespace_names, "default")
    end
  end

  describe "namespaced scoped resources" do
    @tag integration: true
    test "creating a resource", %{conn: conn, test_id: test_id} do
      pod = build_pod("k8s-ex-#{test_id}")
      operation = K8s.Client.create(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result

      operation = K8s.Client.delete(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result
    end

    @tag integration: true
    test "when the request is unauthorized", %{conn: conn} do
      operation = K8s.Client.get("v1", "ServiceAccount", name: "default", namespace: "default")
      unauthorized = %K8s.Conn.Auth.Token{token: "nope"}
      unauthorized_conn = %K8s.Conn{conn | auth: unauthorized}

      {:error, error} = K8s.Client.run(unauthorized_conn, operation)

      assert %K8s.Client.APIError{
               __exception__: true,
               message: "Unauthorized",
               reason: "Unauthorized"
             } == error
    end

    @tag integration: true
    test "getting a resource", %{conn: conn} do
      operation = K8s.Client.get("v1", "ServiceAccount", name: "default", namespace: "default")
      result = K8s.Client.run(conn, operation)

      assert {:ok, %{"apiVersion" => "v1", "kind" => "ServiceAccount"}} = result
    end

    @tag integration: true
    test "getting a resource that doesn't exist returns an error", %{conn: conn} do
      operation = K8s.Client.get("v1", "ServiceAccount", name: "NOPE", namespace: "default")
      {:error, error} = K8s.Client.run(conn, operation)

      assert %K8s.Client.APIError{
               message: "serviceaccounts \"NOPE\" not found",
               reason: "NotFound"
             } == error
    end

    @tag integration: true
    test "applying a resource that does not exist", %{conn: conn, test_id: test_id} do
      pod = build_pod("k8s-ex-#{test_id}")
      operation = K8s.Client.apply(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result

      operation = K8s.Client.delete(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result
    end

    @tag integration: true
    test "applying a resource that does already exist", %{conn: conn, test_id: test_id} do
      pod = build_pod("k8s-ex-#{test_id}")
      # make sure pod is created with no label called "some"
      assert is_nil(pod["metadata"]["labels"]["some"])

      operation = K8s.Client.apply(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result

      pod = put_in(pod, ["metadata", "labels"], %{"some" => "change"})
      operation = K8s.Client.apply(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result

      operation = K8s.Client.get(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, pod} = result

      assert "change" == pod["metadata"]["labels"]["some"]

      operation = K8s.Client.delete(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result
    end

    @tag integration: true
    test "applying a resource with different managers should return a conflict error", %{
      conn: conn,
      test_id: test_id
    } do
      pod = build_pod("k8s-ex-#{test_id}", %{"some" => "init"})

      # make sure pod is created with label "some"
      assert "init" == pod["metadata"]["labels"]["some"]

      operation = K8s.Client.apply(pod, field_manager: "k8s_test_mgr_1", force: false)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result

      pod = put_in(pod, ["metadata", "labels"], %{"some" => "change"})
      operation = K8s.Client.apply(pod, field_manager: "k8s_test_mgr_2", force: false)
      result = K8s.Client.run(conn, operation)

      assert {:error,
              %K8s.Client.APIError{
                message:
                  "Apply failed with 1 conflict: conflict with \"k8s_test_mgr_1\": .metadata.labels.some",
                reason: "Conflict"
              }} == result

      operation = K8s.Client.delete(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result
    end

    @tag integration: true
    test "applying a new status to a deployment", %{conn: conn, test_id: test_id} do
      pod = build_pod("k8s-ex-#{test_id}")
      operation = K8s.Client.apply(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result

      pod_with_status = Map.put(pod, "status", %{"message" => "some message"})

      operation =
        K8s.Client.apply(
          "v1",
          "pods/status",
          [namespace: "default", name: "k8s-ex-#{test_id}"],
          pod_with_status
        )

      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result

      operation = K8s.Client.get(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, pod} = result

      assert "some message" == pod["status"]["message"]

      operation = K8s.Client.delete(pod)
      result = K8s.Client.run(conn, operation)
      assert {:ok, _pod} = result
    end

    @tag integration: true
    test "listing resources", %{conn: conn} do
      operation = K8s.Client.list("v1", "ServiceAccount", namespace: "default")

      assert {:ok,
              %{
                "items" => service_accounts,
                "apiVersion" => "v1",
                "kind" => "ServiceAccountList"
              }} = K8s.Client.run(conn, operation)

      assert length(service_accounts) == 1
    end
  end
end
