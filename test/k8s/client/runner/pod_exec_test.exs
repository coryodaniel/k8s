defmodule K8s.Client.Runner.PodExecTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.PodExec
  alias K8s.Client.Runner.PodExec

  setup do
    {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
    {:ok, %{conn: conn}}
  end

  def operation(name \\ "pods/exec") do
    %K8s.Operation{
      method: :post,
      verb: :create,
      api_version: "v1",
      name: name,
      path_params: [namespace: "test", name: "nginx-pod"]
    }
  end

  describe "run/3" do
    test "returns an error when `:command` is not provided", %{conn: conn} do
      {:error, msg} = PodExec.run(conn, operation(), stdin: true, container: "fluentd")
      assert msg == ":command is required"
    end

    test "returns an error when the operation is not named `pods/exec`", %{conn: conn} do
      operation = operation("pods")
      {:error, msg} = PodExec.run(conn, operation, command: ["date"], stream_to: self())
      assert msg == :unsupported_operation
    end

    test "returns the command results and the websocket exit normal", %{conn: conn} do
      exec_opts = [
        command: ["/bin/sh", "-c", "date"],
        stdin: true,
        stderr: true,
        stdout: true,
        tty: true,
        stream_to: self()
      ]

      {:ok, websocket_pid} = PodExec.run(conn, operation(), exec_opts)
      receive_loop(websocket_pid)
    end
  end

  def receive_loop(websocket_pid) do
    receive do
      {:ok, _message} -> receive_loop(websocket_pid)
      {:exit, reason} -> reason
    after
      5000 ->
        Process.exit(websocket_pid, :kill)
        IO.puts("Timed out waiting for response from pod via websocket")
    end
  end
end
