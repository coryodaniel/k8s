defmodule K8s.Conn.Auth.ExecTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias K8s.Conn
  alias K8s.Conn.Auth.Exec

  test "creates http request from echo" do
    # this test demonstrates the full round trip of kube context into a parsed
    # auth provider and using that provider that's running a
    # genserver. The genserver will shell out to echo
    output =
      Jason.encode!(%{
        "kind" => "ExecCredential",
        "apiVersion" => "client.authentication.k8s.io/v1alpha1",
        "status" => %{
          "token" => "all the batteries are belong to us"
        }
      })

    config = %{
      "exec" => %{
        "apiVersion" => "client.authentication.k8s.io/v1alpha1",
        "command" => "echo",
        "args" => [output]
      }
    }

    {:ok, provider} = Exec.create(config, nil)

    {:ok, %Conn.RequestOptions{headers: headers, ssl_options: ssl_options}} =
      Conn.RequestOptions.generate(provider)

    assert headers == [{:Authorization, "Bearer all the batteries are belong to us"}]
    assert ssl_options == []
  end
end
