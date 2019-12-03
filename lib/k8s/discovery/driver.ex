defmodule K8s.Discovery.Driver do
  @moduledoc "Driver behaviour for `K8s.Discovery`"

  # TODO: :error_to_handle HTTP errors and bad responses

  @doc """
  List of Kubernetes `apiVersion`s

  ## Examples
      iex> {:ok, conn} = K8s.Cluster.conn(:test)
      ...> JIT.Driver.HTTP.api(conn)
      {:ok, ["v1"]}
  """
  @callback versions(K8s.Conn.t()) :: {:ok, list(String.t())} | :error_to_handle

  @doc """
  List of Kubernetes `APIResourceList`s

  ## Examples
      iex> {:ok, conn} = K8s.Cluster.conn(:test)
      ...> JIT.Driver.HTTP.resources("autoscaling/v1", conn)
      {:ok, [
               %{
                 "kind" => "DaemonSet",
                 "name" => "daemonsets"
               },
               %{
                 "kind" => "Deployment",
                 "name" => "deployments"
               },
               %{
                 "kind" => "Deployment",
                 "name" => "deployments/status"
               }
             ]}
  """
  @callback resources(String.t(), K8s.Conn.t()) :: {:ok, list(Map.t())} | :error_to_handle
end
