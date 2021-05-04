defmodule K8s.Client.Runner.WaitIntegrationTest do
  use ExUnit.Case, async: true
  import K8s.Test.IntegrationHelper

  setup do
    test_id = :rand.uniform(10_000)
    {:ok, %{conn: conn(), test_id: test_id}}
  end

  defp job(name) do
    K8s.Client.create(%{
      "apiVersion" => "batch/v1",
      "kind" => "Job",
      "metadata" => %{"name" => name, "namespace" => "default"},
      "spec" => %{
        "backoffLimit" => 1,
        "template" => %{
          "spec" => %{
            "containers" => [
              %{
                "command" => ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"],
                "image" => "perl",
                "name" => "pi"
              }
            ],
            "restartPolicy" => "Never"
          }
        }
      }
    })
  end

  @tag integration: true
  test "waiting on a job to finish successfully", %{conn: conn, test_id: test_id} do
    create_job = job("wait-job-#{test_id}")
    {:ok, _} = K8s.Client.run(conn, create_job)

    op = K8s.Client.get("batch/v1", :job, namespace: "default", name: "pi")
    opts = [find: ["status", "succeeded"], eval: 1, timeout: 10]

    assert {:ok, result} = K8s.Client.Runner.Wait.run(conn, op, opts)
    assert result["status"]["succeeded"] == 1
  end

  @tag integration: true
  test "using an anonymous function to evaluate a job", %{conn: conn, test_id: test_id} do
    create_job = job("wait-job-#{test_id}")
    {:ok, _} = K8s.Client.run(conn, create_job)

    op = K8s.Client.get("batch/v1", :job, namespace: "default", name: "pi")

    eval_fn = fn value_of_status_succeeded ->
      value_of_status_succeeded == 1
    end

    opts = [find: ["status", "succeeded"], eval: eval_fn, timeout: 10]

    assert {:ok, result} = K8s.Client.Runner.Wait.run(conn, op, opts)
    assert result["status"]["succeeded"] == 1
  end
end
