defmodule K8s.Client.Runner.Async do
  @moduledoc """
  `K8s.Client` runner to process a batch of operations asynchronously.
  """

  alias K8s.Client.Runner.Base
  alias K8s.Operation

  @doc """
  Async run multiple operations. Operations will be returned in same order given.
  Operations will not cease in event of failure.

  ## Example

  Get a list of pods, then map each one to an individual `GET` operation:

    ```elixir
    # Get the pods
    operation = K8s.Client.list("v1", "Pod", namespace: :all)
    {:ok, %{"items" => pods}} = K8s.Client.run(operation, :test_cluster)

    # Map each one to an individual `GET` operation.
    operations = Enum.map(pods, fn(%{"metadata" => %{"name" => name, "namespace" => ns}}) ->
       K8s.Client.get("v1", "Pod", namespace: ns, name: name)
    end)

    # Get the results asynchronously
    results = K8s.Client.Async.run(operations, :test_cluster)
    ```
  """
  @spec run(list(Operation.t()), binary, keyword) :: list({:ok, struct} | {:error, struct})
  def run(operations, cluster_name, opts \\ []) do
    operations
    |> Enum.map(&Task.async(fn -> Base.run(&1, cluster_name, opts) end))
    |> Enum.map(&Task.await/1)
  end
end
