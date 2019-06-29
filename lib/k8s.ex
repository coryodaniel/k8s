defmodule K8s do
  @moduledoc """
  Kubernetes API Client for Elixir
  """

  @doc """
  Initialize ETS tables and register clusters
  """
  def init do
    :ets.new(K8s.Conf, [:set, :public, :named_table])
    :ets.new(K8s.Cluster.Group, [:set, :public, :named_table])
    K8s.Cluster.auto_register_clusters!()
  end

  @doc false
  @spec http_provider() :: module()
  def http_provider do
    Application.get_env(:k8s, :http_provider, K8s.Client.HTTPProvider)
  end
end
