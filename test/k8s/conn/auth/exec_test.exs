defmodule K8s.Conn.Auth.ExecTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias K8s.Conn
  alias K8s.Conn.Auth.Exec

  describe "create/2" do
    test "creates an exec struct from exec data" do
      auth = %{
        "exec" => %{
          "apiVersion" => "client.authentication.k8s.io/v1alpha1",
          "command" => "aws-iam-authenticator"
        }
      }

      assert %Exec{
               command: "aws-iam-authenticator",
               env: %{},
               args: []
             } = Exec.create(auth, nil)
    end

    test "creates an exec struct with function arguments" do
      auth = %{
        "exec" => %{
          "apiVersion" => "client.authentication.k8s.io/v1alpha1",
          "command" => "aws-iam-authenticator",
          "args" => ["token", "-i", "staging"]
        }
      }

      assert %Exec{
               command: "aws-iam-authenticator",
               env: %{},
               args: ["token", "-i", "staging"]
             } = Exec.create(auth, nil)
    end

    test "creates an exec struct with environment variables" do
      auth = %{
        "exec" => %{
          "apiVersion" => "client.authentication.k8s.io/v1alpha1",
          "command" => "aws-iam-authenticator",
          "env" => [%{"name" => "FOO", "value" => "bar"}]
        }
      }

      assert %Exec{
               command: "aws-iam-authenticator",
               env: %{"FOO" => "bar"},
               args: []
             } = Exec.create(auth, nil)
    end

    test "creates an exec struct with null env" do
      auth = %{
        "exec" => %{
          "apiVersion" => "client.authentication.k8s.io/v1alpha1",
          "command" => "aws-iam-authenticator",
          "env" => nil
        }
      }

      assert %Exec{
               command: "aws-iam-authenticator",
               env: %{},
               args: []
             } = Exec.create(auth, nil)
    end
  end

  test "creates http request signing options" do
    response = %{
      "kind" => "ExecCredential",
      "apiVersion" => "client.authentication.k8s.io/v1alpha1",
      "spec" => %{},
      "status" => %{
        "expirationTimestamp" => "2020-07-15T08:36:10Z",
        "token" => "foo"
      }
    }

    provider = %Exec{
      command: "echo",
      args: [Jason.encode!(response)],
      env: %{}
    }

    {:ok, %Conn.RequestOptions{headers: headers, ssl_options: ssl_options}} =
      Conn.RequestOptions.generate(provider)

    assert headers == [{"Authorization", "Bearer foo"}]
    assert ssl_options == []
  end
end
