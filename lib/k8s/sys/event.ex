defmodule K8s.Sys.Event do
  use Notion, name: :k8s

  defevent([:http, :request, :succeeded])
  defevent([:http, :request, :failed])

  defevent([:cluster, :registered])
end
