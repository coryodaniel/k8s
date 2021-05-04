defmodule K8s.MiddlewareTest do
  use ExUnit.Case, async: true

  defmodule EnvLabeler do
    @behaviour K8s.Middleware.Request

    @impl true
    def call(%{body: body} = req) do
      updated_body = put_in(body, ["metadata", "labels"], %{"env" => "prod"})
      updated_req = %K8s.Middleware.Request{req | body: updated_body}
      {:ok, updated_req}
    end
  end

  describe "run/2" do
    test "Applies middleware to a request" do
      {:ok, conn} = K8s.Conn.lookup(:test)

      req = %K8s.Middleware.Request{
        conn: conn,
        url: "http://example.com",
        method: :post,
        body: %{"metadata" => %{"name" => "nginx"}}
      }

      {:ok, %{body: body}} = K8s.Middleware.run(req, [K8s.MiddlewareTest.EnvLabeler])

      assert body == %{"metadata" => %{"name" => "nginx", "labels" => %{"env" => "prod"}}}
    end
  end
end
