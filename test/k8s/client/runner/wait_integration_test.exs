defmodule K8s.Client.Runner.WaitIntegrationTest do
  use ExUnit.Case, async: true
  import K8s.Test.IntegrationHelper

  setup_all do
    conn = conn()

    on_exit(fn ->
      K8s.Client.delete_all("batch/v1", "Job", namespace: "default")
      |> K8s.Selector.label({"k8s-ex-test", "wait"})
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()

      K8s.Client.delete_all("v1", "Pod", namespace: "default")
      |> K8s.Selector.label({"k8s-ex-test", "wait"})
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()
    end)

    [conn: conn]
  end

  setup do
    timeout =
      "TEST_WAIT_TIMEOUT"
      |> System.get_env("10")
      |> String.to_integer()

    test_id = :rand.uniform(10_000)
    labels = %{"k8s-ex-watch-test" => "#{test_id}", "k8s-ex-test" => "wait"}

    [test_id: test_id, labels: labels, timeout: timeout]
  end

  @spec job(binary, keyword) :: K8s.Operation.t()
  defp job(name, opts) do
    %{
      "apiVersion" => "batch/v1",
      "kind" => "Job",
      "metadata" => %{
        "name" => name,
        "namespace" => "default",
        "labels" => Keyword.get(opts, :labels, %{})
      },
      "spec" => %{
        "backoffLimit" => 1,
        "template" => %{
          "metadata" => %{"labels" => Keyword.get(opts, :labels, %{})},
          "spec" => %{
            "containers" => [
              %{
                "command" => ["perl", "-Mbignum=bpi", "-wle", "print bpi(3)"],
                "image" => "perl",
                "name" => "pi"
              }
            ],
            "restartPolicy" => "Never"
          }
        }
      }
    }
  end

  @tag :integration
  @tag :wait
  test "waiting on a job to finish successfully", %{
    conn: conn,
    test_id: test_id,
    labels: labels,
    timeout: timeout
  } do
    {:ok, _} =
      "wait-job-#{test_id}"
      |> job(labels: labels)
      |> K8s.Client.create()
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()

    opts = [find: ["status", "succeeded"], eval: 1, timeout: timeout]

    assert {:ok, result} =
             K8s.Client.get("batch/v1", :job, namespace: "default", name: "wait-job-#{test_id}")
             |> K8s.Client.put_conn(conn)
             |> K8s.Client.wait_until(opts)

    assert result["status"]["succeeded"] == 1
  end

  @tag :integration
  @tag :wait
  test "using an anonymous function to evaluate a job", %{
    conn: conn,
    test_id: test_id,
    labels: labels,
    timeout: timeout
  } do
    create_job =
      "wait-job-#{test_id}"
      |> job(labels: labels)
      |> K8s.Client.create()

    {:ok, _} = K8s.Client.run(conn, create_job)

    op = K8s.Client.get("batch/v1", :job, namespace: "default", name: "wait-job-#{test_id}")

    eval_fn = fn value_of_status_succeeded ->
      value_of_status_succeeded == 1
    end

    opts = [find: ["status", "succeeded"], eval: eval_fn, timeout: timeout]

    assert {:ok, result} = K8s.Client.Runner.Wait.run(conn, op, opts)
    assert result["status"]["succeeded"] == 1
  end
end
