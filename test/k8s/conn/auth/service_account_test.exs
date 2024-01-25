defmodule K8s.Conn.Auth.ServiceAccountTest do
  use ExUnit.Case, async: true

  alias K8s.Conn.Auth.ServiceAccount

  describe "create/2" do
    test "create returns an error if path doesn't exist" do
      # Even though the genserver will read in the background it's important
      # for usability that misconfiguration is caught early.
      #
      # Test to make sure some sanity checks are working.
      assert {:error, _} = ServiceAccount.create("nonexistent", "anything")
    end

    test "create starts a worker if the path exists" do
      assert {:ok, %ServiceAccount{target: _}} =
               ServiceAccount.create("test/support/tls/token", "anything")
    end
  end

  describe "full cycle" do
    test "get_token/1 returns a token" do
      # Can create the provider
      {:ok, provider} = ServiceAccount.create("test/support/tls/token", "anything")

      # The provider generates the expected request options
      {:ok, %K8s.Conn.RequestOptions{headers: headers, ssl_options: ssl_options}} =
        K8s.Conn.RequestOptions.generate(provider)

      assert headers == [{:Authorization, "Bearer imatoken"}]
      assert ssl_options == []
    end
  end
end
