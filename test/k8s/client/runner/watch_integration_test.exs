defmodule K8s.Client.Runner.WatchIntegrationTest do
  use ExUnit.Case, async: false
  import K8s.Test.IntegrationHelper

  setup_all do
    conn = conn()

    on_exit(fn ->
      K8s.Client.delete_all("v1", "Pod", namespace: "default")
      |> K8s.Selector.label({"k8s-ex-test", "watch"})
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()
    end)

    [conn: conn]
  end

  setup do
    test_id = :rand.uniform(10_000)
    labels = %{"k8s-ex-watch-test" => "#{test_id}", "k8s-ex-test" => "watch"}

    {:ok, %{test_id: test_id, labels: labels}}
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

          Process.sleep(200)

          send(pid, {ref, type, name})
        end)

      [
        handle_stream: handle_stream,
        resource_name: "watch-nginx-#{test_id}",
        timeout: timeout
      ]
    end

    @tag :integration
    test "watches and streams a resource list", %{
      conn: conn,
      labels: labels,
      handle_stream: handle_stream,
      resource_name: resource_name,
      timeout: timeout
    } do
      selector = K8s.Selector.label(labels)
      operation = K8s.Client.watch("v1", "ConfigMap", namespace: "default")
      operation = K8s.Operation.put_selector(operation, selector)

      Task.start(fn ->
        {:ok, event_stream} = K8s.Client.stream(conn, operation)
        event_stream |> handle_stream.() |> Stream.run()
      end)

      Process.sleep(500)

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

    @tag :integration
    test "watches and streams resources in all namespaces", %{
      conn: conn,
      labels: labels,
      handle_stream: handle_stream,
      resource_name: resource_name,
      timeout: timeout
    } do
      selector = K8s.Selector.label(labels)
      operation = K8s.Client.watch("v1", "ConfigMap", namespace: :all)
      operation = K8s.Operation.put_selector(operation, selector)

      Task.start(fn ->
        {:ok, event_stream} = K8s.Client.stream(conn, operation)
        event_stream |> handle_stream.() |> Stream.run()
      end)

      Process.sleep(500)

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

    @tag :integration
    test "watches and streams a signle resource", %{
      conn: conn,
      labels: labels,
      handle_stream: handle_stream,
      resource_name: resource_name,
      timeout: timeout
    } do
      selector = K8s.Selector.label(labels)
      operation = K8s.Client.watch("v1", "ConfigMap", namespace: "default", name: resource_name)
      operation = K8s.Operation.put_selector(operation, selector)

      Task.start(fn ->
        {:ok, event_stream} = K8s.Client.stream(conn, operation)
        event_stream |> handle_stream.() |> Stream.run()
      end)

      Process.sleep(500)

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
      operation = K8s.Client.watch("v1", "ConfigMap", namespace: "default")
      operation = K8s.Operation.put_selector(operation, selector)

      Task.start(fn ->
        {:ok, event_stream} = K8s.Client.stream(conn, operation)
        event_stream |> handle_stream.() |> Stream.run()
      end)

      Process.sleep(500)

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
