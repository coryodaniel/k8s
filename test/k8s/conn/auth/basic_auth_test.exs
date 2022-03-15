defmodule K8s.Conn.Auth.BasicAuthTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias K8s.Conn
  alias K8s.Conn.Auth.BasicAuth

  describe "create/2" do
    test "creates a BasicAuth struct from token data" do
      auth = %{"username" => "basic-auth-username", "password" => "basic-auth-password"}

      assert {:ok, %BasicAuth{token: "YmFzaWMtYXV0aC11c2VybmFtZTpiYXNpYy1hdXRoLXBhc3N3b3Jk"}} =
               BasicAuth.create(auth, nil)
    end
  end

  test "creates http request signing options" do
    {:ok, conn = %Conn{auth: %BasicAuth{token: token}}} =
      Conn.from_file("test/support/kube-config.yaml", user: "basic-auth-user")

    {:ok, %Conn.RequestOptions{headers: headers, ssl_options: ssl_options}} =
      Conn.RequestOptions.generate(conn.auth)

    assert headers == [{:Authorization, "Basic #{token}"}]
    assert ssl_options == []
  end
end
