defmodule K8s do
  @moduledoc """
  Documentation for K8s.
  """

  @http_provider Application.get_env(:k8s, :http_provider, K8s.Client.HTTPProvider)

  @doc """
  Initialize `K8s.Conf` and `K8s.Group` ETS tables
  """
  def init do
    make_table(K8s.Conf)
    make_table(K8s.Group)
    K8s.Cluster.register_clusters()
  end

  def http_provider, do: @http_provider

  defp make_table(name), do: :ets.new(name, [:set, :public, :named_table])
end
