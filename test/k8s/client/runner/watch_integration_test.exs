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

  describe "watch_and_stream" do
    setup %{test_id: test_id} do
      timeout =
        "TEST_WAIT_TIMEOUT"
        |> System.get_env("5")
        |> String.to_integer()
        |> Kernel.*(1000)

      handle_stream =
        &Stream.map(&1, fn evt ->
          pid =
            evt
            |> get_in(~w(object data pid))
            |> String.to_charlist()
            |> :erlang.list_to_pid()

          ref =
            evt
            |> get_in(~w(object data ref))
            |> String.to_charlist()
            |> :erlang.list_to_ref()

          name = get_in(evt, ~w(object metadata name))
          type = evt["type"]

          send(pid, {ref, type, name})
        end)

      [
        handle_stream: handle_stream,
        resource_name: "watch-nginx-#{test_id}",
        timeout: timeout
      ]
    end

    @tag integration: true
    test "watches and streams a resource list", %{
      conn: conn,
      labels: labels,
      handle_stream: handle_stream,
      resource_name: resource_name,
      timeout: timeout
    } do
      selector = K8s.Selector.label(labels)
      operation = K8s.Client.list("v1", "ConfigMap", namespace: "default")
      operation = K8s.Operation.put_label_selector(operation, selector)
      {:ok, event_stream} = K8s.Client.Runner.Watch.stream(conn, operation)

      Task.start(fn -> event_stream |> handle_stream.() |> Stream.run() end)
      :timer.sleep(500)

      pid = self()
      ref = make_ref()

      data = %{
        "pid" => pid |> :erlang.pid_to_list() |> List.to_string(),
        "ref" => ref |> :erlang.ref_to_list() |> List.to_string()
      }

      cm = build_configmap(resource_name, data, labels: labels)

      op = K8s.Client.create(cm)
      {:ok, _} = K8s.Client.run(conn, op)
      assert_receive({^ref, "ADDED", ^resource_name}, timeout)

      op =
        cm
        |> put_in(["metadata", Access.key("annotations", %{}), "some"], "value")
        |> Map.delete("spec")
        |> K8s.Client.patch()

      {:ok, _} = K8s.Client.run(conn, op)
      assert_receive({^ref, "MODIFIED", ^resource_name}, timeout)

      op = K8s.Client.delete(cm)
      {:ok, _} = K8s.Client.run(conn, op)
      assert_receive({^ref, "DELETED", ^resource_name}, timeout)
    end

    @tag integration: true
    test "watches and streams a signle resource", %{
      conn: conn,
      labels: labels,
      handle_stream: handle_stream,
      resource_name: resource_name,
      timeout: timeout
    } do
      selector = K8s.Selector.label(labels)
      operation = K8s.Client.get("v1", "ConfigMap", namespace: "default", name: resource_name)
      operation = K8s.Operation.put_label_selector(operation, selector)
      {:ok, event_stream} = K8s.Client.Runner.Watch.stream(conn, operation)

      Task.start(fn -> event_stream |> handle_stream.() |> Stream.run() end)
      :timer.sleep(500)

      pid = self()
      ref = make_ref()

      data = %{
        "pid" => pid |> :erlang.pid_to_list() |> List.to_string(),
        "ref" => ref |> :erlang.ref_to_list() |> List.to_string()
      }

      cm = build_configmap(resource_name, data, labels: labels)

      op = K8s.Client.create(cm)
      {:ok, _} = K8s.Client.run(conn, op)
      assert_receive({^ref, "ADDED", ^resource_name}, timeout)

      op =
        cm
        |> put_in(["metadata", Access.key("annotations", %{}), "some"], "value")
        |> Map.delete("spec")
        |> K8s.Client.patch()

      {:ok, _} = K8s.Client.run(conn, op)
      assert_receive({^ref, "MODIFIED", ^resource_name}, timeout)

      op = K8s.Client.delete(cm)
      {:ok, _} = K8s.Client.run(conn, op)
      assert_receive({^ref, "DELETED", ^resource_name}, timeout)
    end

    # Excluded by default - run with --only reliability
    @tag :reliability
    test "events are created reliably", %{
      conn: conn,
      labels: labels,
      handle_stream: handle_stream,
      timeout: timeout
    } do
      selector = K8s.Selector.label(labels)
      operation = K8s.Client.list("v1", "ConfigMap", namespace: "default")
      operation = K8s.Operation.put_label_selector(operation, selector)
      {:ok, event_stream} = K8s.Client.Runner.Watch.stream(conn, operation)

      Task.start(fn -> event_stream |> handle_stream.() |> Stream.run() end)
      :timer.sleep(500)

      pid = self()
      ref = make_ref()

      data = %{
        "pid" => pid |> :erlang.pid_to_list() |> List.to_string(),
        "ref" => ref |> :erlang.ref_to_list() |> List.to_string()
      }

      for run <- 1..1000 do
        resource_name = "test-rel-#{run}"
        cm = build_configmap(resource_name, data, labels: labels)

        op = K8s.Client.create(cm)
        {:ok, _} = K8s.Client.run(conn, op)
        assert_receive({^ref, "ADDED", ^resource_name}, timeout)

        op = K8s.Client.delete(cm)
        {:ok, _} = K8s.Client.run(conn, op)
        assert_receive({^ref, "DELETED", ^resource_name}, timeout)
      end
    end
  end
end
