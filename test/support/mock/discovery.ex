defmodule Mock.Discovery do
  @moduledoc """
  Mock of `K8s.Discovery`
  """

  @behaviour K8s.Behaviours.DiscoveryProvider

  @impl true
  def resource_definitions_by_group(_cluster_name, _opts \\ []) do
    groups =
      "test/support/mock/data/groups.json"
      |> File.read!()
      |> Jason.decode!()

    {:ok, groups}
  end
end
