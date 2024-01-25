defmodule K8s.Conn.Auth.ExecWorkerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias K8s.Conn.Auth.ExecWorker

  describe "parse_opts/1" do
    test "parse a comman with nothing else" do
      config = %{
        "exec" => %{
          "apiVersion" => "client.authentication.k8s.io/v1alpha1",
          "command" => "aws-iam-authenticator"
        }
      }

      assert ExecWorker.parse_opts(config) == [
               command: "aws-iam-authenticator",
               env: %{},
               args: []
             ]
    end

    test "parse a command with arguments" do
      config = %{
        "exec" => %{
          "apiVersion" => "client.authentication.k8s.io/v1alpha1",
          "command" => "aws-iam-authenticator",
          "args" => ["token", "-i", "staging"]
        }
      }

      assert ExecWorker.parse_opts(config) == [
               command: "aws-iam-authenticator",
               env: %{},
               args: ["token", "-i", "staging"]
             ]
    end

    test "parses a command with with explicit nils for env" do
      config = %{
        "exec" => %{
          "apiVersion" => "client.authentication.k8s.io/v1alpha1",
          "command" => "can-handle-nil-command",
          "env" => nil
        }
      }

      assert ExecWorker.parse_opts(config) == [
               command: "can-handle-nil-command",
               env: %{},
               args: []
             ]
    end
  end

  describe "gen_server behavior" do
    test "start_link/1" do
      assert {:ok, pid} =
               ExecWorker.start_link(
                 command: "echo",
                 env: %{},
                 args: []
               )

      assert Process.alive?(pid)
    end
  end

  describe "get_token/1" do
    @spec start_echo_worker(map()) :: pid() | GenServer.server()
    defp start_echo_worker(%{} = cred) do
      # A helper to start an echo worker with a given ExecCredential
      output = Jason.encode!(cred)

      {:ok, pid} =
        ExecWorker.start_link(
          command: "echo",
          env: %{},
          args: [output]
        )

      pid
    end

    test "returns an error when given an unparsable response" do
      {:ok, pid} =
        ExecWorker.start_link(
          command: "echo",
          env: %{},
          args: []
        )

      assert {:error, %Jason.DecodeError{}} = ExecWorker.get_token(pid)
    end

    test "returns an error when given an echo with no token" do
      cred = %{
        "kind" => "ExecCredential",
        "apiVersion" => "client.authentication.k8s.io/v1alpha1",
        "status" => %{}
      }

      pid = start_echo_worker(cred)

      assert {:error, %K8s.Conn.Error{}} = ExecWorker.get_token(pid)
    end

    test "returns a token given an echo with default tokens" do
      cred = %{
        "kind" => "ExecCredential",
        "apiVersion" => "client.authentication.k8s.io/v1alpha1",
        "status" => %{
          "token" => "we need more power"
        }
      }

      pid = start_echo_worker(cred)

      assert {:ok, "we need more power"} = ExecWorker.get_token(pid)
    end

    test "gives the token when a token is not expired" do
      expiration =
        DateTime.utc_now()
        |> DateTime.add(100, :hour)
        |> DateTime.to_string()

      cred = %{
        "kind" => "ExecCredential",
        "apiVersion" => "client.authentication.k8s.io/v1",
        "status" => %{
          "token" => "with great power comes great responsibility",
          "expirationTimestamp" => expiration
        }
      }

      pid = start_echo_worker(cred)

      assert {:ok, "with great power comes great responsibility"} = ExecWorker.get_token(pid)
    end

    test "give an error when the token is expired" do
      expiration =
        DateTime.utc_now()
        |> DateTime.add(-100, :hour)
        |> DateTime.to_string()

      cred = %{
        "kind" => "ExecCredential",
        "apiVersion" => "client.authentication.k8s.io/v1beta1",
        "status" => %{
          "token" => "it's expired",
          "expirationTimestamp" => expiration
        }
      }

      pid = start_echo_worker(cred)

      assert {:error, _} = ExecWorker.get_token(pid)
    end
  end
end
