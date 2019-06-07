defmodule K8s.Conf.Auth.AuthProviderTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias K8s.Conf
  alias K8s.Conf.Auth.AuthProvider

  describe "create/2" do
    test "creates a AuthProvider struct from auth-provider data" do
      auth = %{
        "auth-provider" => %{
          "config" => %{
            "access-token" => "",
            "cmd-args" => "config config-helper --format=json",
            "cmd-path" => "/Users/user/google-cloud-sdk/bin/gcloud",
            "expiry" => "2018-10-29 21:06:53",
            "expiry-key" => "{.credential.token_expiry}",
            "token-key" => "{.credential.access_token}"
          },
          "name" => "gcp"
        }
      }

      assert %AuthProvider{
               cmd_args: ["config", "config-helper", "--format=json"],
               cmd_path: "/Users/user/google-cloud-sdk/bin/gcloud",
               expiry_key: ["credential", "token_expiry"],
               token_key: ["credential", "access_token"]
             } = AuthProvider.create(auth, nil)
    end
  end

  test "creates http request signing options" do
    response = %{
      "credential" => %{
        "access_token" => "foo"
      }
    }

    provider = %AuthProvider{
      cmd_args: [Jason.encode!(response)],
      cmd_path: "echo",
      expiry_key: ["credential", "token_expiry"],
      token_key: ["credential", "access_token"]
    }

    {:ok, %Conf.RequestOptions{headers: headers, ssl_options: ssl_options}} =
      Conf.RequestOptions.generate(provider)

    assert headers == [{"Authorization", "Bearer foo"}]
    assert ssl_options == []
  end
end
