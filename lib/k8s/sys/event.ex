defmodule K8s.Sys.Event do
  @moduledoc false
  use Notion, name: :k8s

  @doc "K8s.Client.HTTPProvider request succeeded"
  defevent([:http, :request, :succeeded])

  @doc "K8s.Client.HTTPProvider request failed"
  defevent([:http, :request, :failed])

  @doc "When a cluster is successfully registered"
  defevent([:cluster, :registered])
end
