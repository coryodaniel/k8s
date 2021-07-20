defmodule K8s.Discovery.Driver do
  @moduledoc "Driver behaviour for `K8s.Discovery`"

  @typedoc """
  Errors returned by adapters should return an error tuple with an `atom()` describing the error or alternatively an "error" struct with more details.

  ## Examples
  ```elixir
  {:error, :file_not_found}
  ```

  ```elixir
  {:error, %K8s.Discovery.Driver.MyDriver.FileNotFoundError{config: "path-to-file"}}
  ```
  """
  @type driver_error_t :: {:error, atom() | struct()}

  @doc """
  List of Kubernetes `apiVersion`s

  ## Examples
      iex> {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
      ...> K8s.Discovery.Driver.HTTP.api(conn)
      {:ok, ["v1"]}
  """
  @callback versions(conn :: K8s.Conn.t()) :: {:ok, list(String.t())} | driver_error_t
  @callback versions(conn :: K8s.Conn.t(), opts :: Keyword.t()) ::
              {:ok, list(String.t())} | driver_error_t

  @doc """
  List of Kubernetes `APIResourceList`s

  ## Examples
      iex> {:ok, conn} = K8s.Conn.from_file("test/support/kube-config.yaml")
      ...> K8s.Discovery.Driver.HTTP.resources("autoscaling/v1", conn)
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
  @callback resources(api_version :: String.t(), conn :: K8s.Conn.t()) ::
              {:ok, list(map())} | driver_error_t
  @callback resources(api_version :: String.t(), conn :: K8s.Conn.t(), opts :: Keyword.t()) ::
              {:ok, list(map())} | driver_error_t
end
