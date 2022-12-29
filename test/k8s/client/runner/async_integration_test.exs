defmodule K8s.Client.Runner.AsyncIntegrationTest do
  use ExUnit.Case, async: true
  import K8s.Test.IntegrationHelper

  setup do
    test_id = :rand.uniform(10_000)
    {:ok, %{conn: conn(), test_id: test_id}}
  end

  @spec pod(binary) :: K8s.Operation.t()
  defp pod(name) do
    name
    |> build_pod
    |> K8s.Client.create()
  end

  @tag :integration
  test "performs multiple operations async", %{conn: conn, test_id: test_id} do
    pod1 = pod("async-nginx-#{test_id}-1")
    {:ok, _} = K8s.Client.run(conn, pod1)

    pod2 = pod("async-nginx-#{test_id}-2")
    {:ok, _} = K8s.Client.run(conn, pod2)

    pods_to_get = [
      %{"name" => "async-nginx-#{test_id}-1", "namespace" => "default"},
      %{"name" => "async-nginx-#{test_id}-2", "namespace" => "default"}
    ]

    operations =
      Enum.map(pods_to_get, fn %{"name" => name, "namespace" => ns} ->
        K8s.Client.get("v1", "Pod", namespace: ns, name: name)
      end)

    pod_list = K8s.Client.Runner.Async.run(conn, operations)

    # eh, the result shape here is gross...
    # [ok: pod1, ok: pod2]
    assert {:ok, _} = pod_list |> List.first()
    assert {:ok, _} = pod_list |> List.last()

    pod_list
    |> Enum.each(fn {:ok, pod} ->
      K8s.Client.run(conn, K8s.Client.delete(pod))
    end)
  end
end
