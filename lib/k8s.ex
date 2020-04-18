defmodule K8s do
  @moduledoc "Kubernetes API Client for Elixir"

  @doc false
  @spec http_provider() :: module()
  def http_provider do
    Application.get_env(:k8s, :http_provider, K8s.Client.HTTPProvider)
  end

  @doc false
  @spec websocket_provider() :: module()
  def websocket_provider do
    Application.get_env(:k8s, :websocket_provider, K8s.Client.WebSocketProvider)
  end

end
