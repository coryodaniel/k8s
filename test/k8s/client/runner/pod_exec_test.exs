defmodule K8s.Client.Runner.PodExecTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.PodExec
  alias K8s.Client.Runner.PodExec

  setup do
    {:ok, %{conn: %K8s.Conn{}}}
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
    test "returns an error when `:command` is not provided", %{conn: conn}  do
      {:error, msg} = PodExec.run(operation(), conn, [stdin: true, container: "fluentd"])
      assert msg == ":command is required"
    end

    test "returns an error when the operation is not named `pods/exec`", %{conn: conn} do
      operation = operation("pods")
      {:error, msg} = PodExec.run(operation, conn, [command: ["date"], stream_to: self()])
      assert msg == :unsupported_operation
    end
  end
end
