defmodule K8s do
  @moduledoc """
  Documentation for K8s.
  """

  @doc """
  Initialize `K8s.Conf` and `K8s.Router` ETS tables
  """
  def init do
    make_table(K8s.Conf)
    make_table(K8s.Router)
    K8s.Cluster.register_clusters()
  end

  defp make_table(name), do: :ets.new(name, [:set, :public, :named_table])
end
