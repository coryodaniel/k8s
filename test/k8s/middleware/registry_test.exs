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
    test "returns an empty list when none are registered", %{test: id} do
      assert [] == Registry.list(id, :request)
    end

    test "returns registered middlewares modules", %{test: id} do
      mw = K8s.Middleware.RegistryTest.FooMiddleware
      :ok = Registry.add(id, :request, mw)
      middlewares = Registry.list(id, :request)

      assert middlewares == [K8s.Middleware.RegistryTest.FooMiddleware]
    end
  end

  test "adding a middleware", %{test: id} do
    mw = K8s.Middleware.RegistryTest.FooMiddleware
    :ok = Registry.add(id, :request, mw)

    middlewares = Agent.get(Registry, & &1[id])
    assert middlewares == %{request: [K8s.Middleware.RegistryTest.FooMiddleware]}
  end

  test "setting the middleware stack", %{test: id} do
    mw = K8s.Middleware.RegistryTest.FooMiddleware
    :ok = Registry.add(id, :request, mw)

    stack = [
      K8s.Middleware.RegistryTest.BarMiddleware,
      K8s.Middleware.RegistryTest.FooMiddleware
    ]

    :ok = Registry.set(id, :request, stack)

    middlewares = Agent.get(Registry, & &1[id])

    assert middlewares == %{
             request: [
               K8s.Middleware.RegistryTest.BarMiddleware,
               K8s.Middleware.RegistryTest.FooMiddleware
             ]
           }
  end
end
