defmodule Mock.API do
  @moduledoc """
  Mock of `K8s.API`
  """

  def groups(_) do
    "test/support/mock/data/groups.json"
    |> File.read!()
    |> Jason.decode!()
  end
end
