defmodule K8s.Client.Runner.Async do
  @moduledoc """
  `K8s.Client` runner to process a batch of operations in parallel.
  """

  alias K8s.Client.Runner.Base
  alias K8s.{Conn, Operation}

  @doc """
  Runs multiple operations in parallel. Operations will be returned in same order given.
  Operations will not cease in event of failure.

  ## Example

  Get a list of pods in parallel:

    ```elixir
    pods_to_get = [
      %{"name" => "nginx", "namespace" => "default"},
      %{"name" => "redis", "namespace" => "default"}
    ]

    # Map each one to an individual `GET` operation.
    operations = Enum.map(pods_to_get, fn(%{"name" => name, "namespace" => ns}) ->
       K8s.Client.get("v1", "Pod", namespace: ns, name: name)
    end)

    # Get the results asynchronously
    {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
    results = K8s.Client.Runner.Async.run(conn, operations)
    ```
  """
  @spec run(Conn.t(), list(Operation.t()), keyword) :: list(Base.result_t())
  def run(%Conn{} = conn, operations, http_opts \\ []) do
    operations
    |> Enum.map(&Task.async(fn -> Base.run(conn, &1, http_opts) end))
    |> Enum.map(&Task.await/1)
  end
end
