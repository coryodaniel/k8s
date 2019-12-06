defmodule K8s.Cluster do
  @moduledoc """
  Cluster configuration and API route store for `K8s.Client`
  """

  alias K8s.{Cluster, Conn, Operation}

  @doc """
  Retrieve the URL for a `K8s.Operation`

  ## Examples

      iex> conn = K8s.Conn.from_file("./test/support/kube-config.yaml")
      ...> operation = K8s.Operation.build(:get, "apps/v1", :deployments, [namespace: "default", name: "nginx"])
      ...> K8s.Cluster.url_for(operation, conn)
      {:ok, "https://localhost:6443/apis/apps/v1/namespaces/default/deployments/nginx"}

  """
  @spec url_for(Operation.t(), Conn.t()) :: {:ok, binary} | {:error, atom(), binary()}
  def url_for(
        %Operation{api_version: api_version, name: name, verb: _verb} = operation,
        %Conn{} = conn
      ) do
    with {:ok, name} <-
           Cluster.Group.resource_name_for_kind(conn, api_version, name),
         operation <- Map.put(operation, :name, name),
         {:ok, path} <- Operation.to_path(operation) do
      {:ok, Path.join(conn.url, path)}
    end
  end

  @doc """
  List registered cluster names
  """
  @spec list() :: list(atom)
  def list() do
    K8s.refactor(__ENV__)
    Map.keys(K8s.Conn.Config.all())
  end
end
