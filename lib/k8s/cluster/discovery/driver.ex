defmodule K8s.Cluster.Discovery.Driver do
  @moduledoc """
  Behaviour for `K8s.Cluster.Discovery`
  """

  @doc "List of Kubernetes `apiVersion`s"
  @callback api_versions(atom(), Keyword.t()) :: {:ok, list(binary())} | {:error, atom()}

  @doc "List of Kubernetes `APIResourceList`s"
  @callback resource_definitions(atom(), Keyword.t()) :: {:ok, list(map())} | {:error, atom()}
end
