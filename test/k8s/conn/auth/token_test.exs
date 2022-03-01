defmodule K8s.Conn.Auth.TokenTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias K8s.Conn
  alias K8s.Conn.Auth.Token

  describe "create/2" do
    test "creates a Token struct from token data" do
      auth = %{"token" => "wee"}
      assert {:ok, %Token{token: "wee"}} = Token.create(auth, nil)
    end
  end

  test "creates http request signing options" do
    {:ok, conn = %Conn{auth: %Token{token: token}}} =
      Conn.from_file("test/support/kube-config.yaml", user: "token-user")

    {:ok, %Conn.RequestOptions{headers: headers, ssl_options: ssl_options}} =
      Conn.RequestOptions.generate(conn.auth)

    assert headers == [Authorization: "Bearer #{token}"]
    assert ssl_options == []
  end
end
