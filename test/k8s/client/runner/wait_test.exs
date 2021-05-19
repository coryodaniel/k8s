defmodule K8s.Client.Runner.WaitTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.Wait
  alias K8s.Client.Runner.Wait

  def operation(method \\ :get) do
    %K8s.Operation{
      method: method,
      verb: :get,
      api_version: "v1",
      name: "Pod",
      path_params: [namespace: "test", name: "nginx-pod"]
    }
  end

  describe "run/3" do
    test "returns an error when `:find` is not provided" do
      {:error, msg} = Wait.run(%K8s.Conn{}, operation(), eval: 1)
      assert msg == ":find is required"
    end

    test "returns an error when `:eval` is not provided" do
      {:error, msg} = Wait.run(%K8s.Conn{}, operation(), find: ["foo"])
      assert msg == ":eval is required"
    end

    test "returns an error the operation is not a GET" do
      operation = operation(:post)
      {:error, msg} = Wait.run(operation, %K8s.Conn{}, find: ["foo"])
      assert Regex.match?(~r/Only HTTP GET operations are supported/, msg)
    end

    test "returns an :ok tuple when the primitive conditions are met" do
      processor = fn _, _ -> {:ok, %{"foo" => "bar"}} end
      opts = [find: ["foo"], eval: "bar", processor: processor]

      assert {:ok, _} = Wait.run(%K8s.Conn{}, operation(), opts)
    end

    test "returns :ok when evaluating with a function" do
      processor = fn _, _ -> {:ok, %{"foo" => "bar"}} end
      eval = fn val -> val == "bar" end
      opts = [find: ["foo"], eval: eval, processor: processor]

      assert {:ok, _} = Wait.run(%K8s.Conn{}, operation(), opts)
    end

    test "returns :ok when finding with a function" do
      processor = fn _, _ -> {:ok, %{"foo" => "bar"}} end
      find = fn result -> result["foo"] end
      opts = [find: find, eval: "bar", processor: processor]

      assert {:ok, _} = Wait.run(%K8s.Conn{}, operation(), opts)
    end

    test "timeouting out" do
      processor = fn _, _ ->
        Process.sleep(1001)
        {:ok, %{"foo" => "bar"}}
      end

      opts = [find: ["foo"], eval: "bar", processor: processor, timeout: 1]

      assert {:ok, _} = Wait.run(%K8s.Conn{}, operation(), opts)
    end
  end
end
