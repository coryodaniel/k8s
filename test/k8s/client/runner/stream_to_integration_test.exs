defmodule K8s.Client.Runner.StreamToIntegrationTest do
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

  @tag :integration
  test "getting a resource", %{conn: conn} do
    operation = K8s.Client.get("v1", "Namespace", name: "default")
    result = K8s.Client.Runner.Base.stream_to(conn, operation, [], self())

    assert :ok = result
    assert_receive {:status, 200}
    assert_receive {:headers, _headers}
    assert_receive {:data, _data}
    assert_receive {:done, true}
  end

  @tag :integration
  @tag :websocket
  test "streams :connect operations to process and accepts messages", %{
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

    {:ok, send_to_webstream} =
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
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.stream_to(pid)

    assert_receive {:open, true}, 2000

    send_to_webstream.({:stdin, ~s(echo "ok"\n)})
    assert_receive {:stdout, "ok\n"}, 2000

    send_to_webstream.(:close)
  end
end
