defmodule K8s.Conn.Auth.AzureTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias K8s.Conn
  alias K8s.Conn.Auth.Azure

  describe "create/2" do
    test "creates a Azure struct from  data" do
      non_expired_unix_ts = DateTime.utc_now() |> DateTime.add(10, :minute) |> DateTime.to_unix()

      auth = %{
        "auth-provider" => %{
          "config" => %{
            "access-token" => "xxx",
            "apiserver-id" => "service_id",
            "client-id" => "client_id",
            "expires-on" => "#{non_expired_unix_ts}",
            "refresh-token" => "yyy",
            "tenant-id" => "tenant"
          },
          "name" => "azure"
        }
      }

      assert {:ok,
              %Azure{
                token: "xxx"
              }} = Azure.create(auth, nil)
    end
  end

  test "creates http request signing options" do
    provider = %Azure{
      token: "xxx"
    }

    {:ok, %Conn.RequestOptions{headers: headers, ssl_options: ssl_options}} =
      Conn.RequestOptions.generate(provider)

    assert headers == [{:Authorization, "Bearer xxx"}]
    assert ssl_options == []
  end
end
