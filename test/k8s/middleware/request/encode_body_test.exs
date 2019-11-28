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

  test "returns an error when the body cannot be encoded" do
    data = [should: :fail]
    request = %K8s.Middleware.Request{body: data, method: :post}
    result = K8s.Middleware.Request.EncodeBody.call(request)

    assert result ==
             {:error,
              %Protocol.UndefinedError{
                description: "Jason.Encoder protocol must always be explicitly implemented",
                protocol: Jason.Encoder,
                value: {:should, :fail}
              }}
  end
end
