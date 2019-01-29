defmodule Mock.Discovery do
  @moduledoc """
  Mock of `K8s.Discovery`
  """

  def versions(_, _opts \\ []) do
    ["fuck"]
  end

  def groups(_) do
    "test/support/mock/data/groups.json"
    |> File.read!()
    |> Jason.decode!()
  end
end
