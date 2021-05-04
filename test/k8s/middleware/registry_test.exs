defmodule K8s.Middleware.RegistryTest do
  use ExUnit.Case, async: false
  alias K8s.Middleware.Registry

  defmodule BarMiddleware do
    @behaviour K8s.Middleware.Request
    @impl true
    def call(req), do: {:ok, req}
  end

  defmodule FooMiddleware do
    @behaviour K8s.Middleware.Request
    @impl true
    def call(req), do: {:ok, req}
  end

  describe "list/2" do
    test "returns default middleware when none are registered", %{test: id} do
      expected = [K8s.Middleware.Request.Initialize, K8s.Middleware.Request.EncodeBody]
      actual = Registry.list(id, :request)
      assert expected == actual
    end
  end

  describe "add/3" do
    test "adds middleware modules to the end of the stack", %{test: id} do
      :ok = Registry.add(id, :request, K8s.Middleware.RegistryTest.FooMiddleware)

      expected = [
        K8s.Middleware.Request.Initialize,
        K8s.Middleware.Request.EncodeBody,
        K8s.Middleware.RegistryTest.FooMiddleware
      ]

      middleware = Agent.get(Registry, & &1[id])
      actual = middleware.request
      assert expected == actual
    end
  end

  describe "set/3" do
    test "replaces the existing middleware stack", %{test: id} do
      mw = K8s.Middleware.RegistryTest.FooMiddleware
      :ok = Registry.add(id, :request, mw)

      expected = [
        K8s.Middleware.RegistryTest.BarMiddleware,
        K8s.Middleware.RegistryTest.FooMiddleware
      ]

      :ok = Registry.set(id, :request, expected)

      middlewares = Agent.get(Registry, & &1[id])
      actual = middlewares.request

      assert expected == actual
    end
  end
end
