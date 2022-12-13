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
  test "runs :connect operations and returns stdout", %{
    conn: conn,
    labels: labels,
    test_id: test_id
  } do
    pod = pod("stream-nginx-#{test_id}-1", labels)
    {:ok, created_pod} = K8s.Client.run(conn, pod)

    {:ok, _} =
      K8s.Client.wait_until(conn, K8s.Client.get(created_pod),
        find: ["status", "containerStatuses", Access.filter(&(&1["ready"] == true))],
        eval: &match?([_ | _], &1),
        timeout: 60
      )

    {:ok, response} =
      K8s.Client.run(
        conn,
        K8s.Client.connect(
          created_pod["apiVersion"],
          "pods/exec",
          [namespace: K8s.Resource.namespace(created_pod), name: K8s.Resource.name(created_pod)],
          command: ["/bin/sh", "-c", ~s(echo "ok")],
          tty: false
        )
      )

    assert response.stdout =~ "ok"
  end

  @tag :integration
  test "runs :connect operations and returns errors", %{
    conn: conn,
    labels: labels,
    test_id: test_id
  } do
    pod = pod("stream-nginx-#{test_id}-1", labels)
    {:ok, created_pod} = K8s.Client.run(conn, pod)

    {:ok, _} =
      K8s.Client.wait_until(conn, K8s.Client.get(created_pod),
        find: ["status", "containerStatuses", Access.filter(&(&1["ready"] == true))],
        eval: &match?([_ | _], &1),
        timeout: 60
      )

    {:ok, response} =
      K8s.Client.run(
        conn,
        K8s.Client.connect(
          created_pod["apiVersion"],
          "pods/exec",
          [namespace: K8s.Resource.namespace(created_pod), name: K8s.Resource.name(created_pod)],
          command: ["/bin/sh", "-c", "no-such-command"],
          tty: false
        )
      )

    assert response.error =~ "error executing command"
    assert response.stderr =~ "not found"
  end

  @tag :integration
  test "runs :connect operations and accepts messages", %{
    conn: conn,
    labels: labels,
    test_id: test_id
  } do
    pod = pod("stream-nginx-#{test_id}-1", labels)
    {:ok, created_pod} = K8s.Client.run(conn, pod)

    {:ok, _} =
      K8s.Client.wait_until(conn, K8s.Client.get(created_pod),
        find: ["status", "containerStatuses", Access.filter(&(&1["ready"] == true))],
        eval: &match?([_ | _], &1),
        timeout: 60
      )

    pid = self()

    task =
      Task.async(fn ->
        {:ok, stream} =
          K8s.Client.stream(
            conn,
            K8s.Client.connect(
              created_pod["apiVersion"],
              "pods/exec",
              [
                namespace: K8s.Resource.namespace(created_pod),
                name: K8s.Resource.name(created_pod)
              ],
              command: ["/bin/sh"],
              tty: false
            )
          )

        stream |> Stream.map(fn chunk -> send(pid, chunk) end) |> Stream.run()
      end)

    assert_receive :open, 2000

    send(task.pid, {:stdin, ~s(echo "ok"\n)})
    send(task.pid, :close)

    assert_receive {:stdout, "ok\n"}, 2000
  end

  @tag :integration
  test "returns error if connection fails", %{conn: conn} do
    result =
      K8s.Client.run(
        conn,
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
      )

    assert {:error, error} = result
    assert error.message =~ "404"
  end
end
