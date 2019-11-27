defmodule K8s.Middleware.Request.EncodeBodyTest do
  use ExUnit.Case, async: true

  test "encode JSON payloads when given a modifying HTTP verb" do
    data = %{"hello" => "world"}
    request = %K8s.Middleware.Request{body: data, method: :put}
    {:ok, %{body: body}} = K8s.Middleware.Request.EncodeBody.call(request)

    assert body == ~s({"hello":"world"})
  end

  test "returns an empty string if not a modifying verb" do
    data = %{"hello" => "world"}
    request = %K8s.Middleware.Request{body: data, method: :get}
    {:ok, %{body: body}} = K8s.Middleware.Request.EncodeBody.call(request)

    assert body == ""
  end

  # TODO: handle error return here type
  # test "failure" do
  #   data = [should: :fail]
  #   request = %K8s.Middleware.Request{body: data, method: :post}
  #   {:ok, %{body: body}} = K8s.Middleware.Request.EncodeBody.call(request)

  #   assert body == ""
  # end
end
