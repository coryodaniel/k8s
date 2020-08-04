defmodule K8s do
  @moduledoc "Kubernetes API Client for Elixir"

  @doc false
  @spec http_provider() :: module()
  @deprecated "Call K8s.default_http_provider/0 instead"
  def http_provider, do: default_http_provider()
  
  @doc "Returns the default HTTP Provider"
  @spec http_provider() :: module()
  def default_http_provider do
    Application.get_env(:k8s, :http_provider, K8s.Client.HTTPProvider)
  end
end
