defmodule K8s.Conf.Auth.TokenTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias K8s.Conf
  alias K8s.Conf.Auth.Token

  describe "create/2" do
    test "creates a Token struct from token data" do
      auth = %{"token" => "wee"}
      assert %Token{token: token} = Token.create(auth, nil)
      assert token
    end
  end

  describe "sign/1" do
    test "creates http request signing options" do
      config = Conf.from_file("test/support/kube-config.yaml", user: "token-user")
      assert %Token{token: token} = config.auth

      %Conf.RequestOptions{headers: headers, ssl_options: ssl_options} =
        Conf.RequestOptions.generate(config.auth)

      assert headers == [{"Authorization", "Bearer #{token}"}]
      assert ssl_options == []
    end
  end
end
