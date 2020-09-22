defmodule K8s.Client.Declarative do
  @moduledoc """
  Declarative functions for the K8s.Client module.
  """

  alias K8s.Client.Imperative
  alias K8s.Client.Runner.Base
  alias K8s.Conn

  @last_applied_configuration_annotation "ex.kubernetes.io/last-applied-configuration"

  @doc """
  Inspired by `kubectl apply`, updates a given resource on the cluster, while recording the previous state in the annotation `(#{@last_applied_configuration_annotation})`. Since the apply has to check whether the resource already
  exists in the cluster, it requires the run() operation to be passed as a callback. Finally, this function applies the
  resource to the cluster directly by calling the run callback.

  ## Examples

      iex>  deployment = %{
      ...>    "apiVersion" => "apps/v1",
      ...>    "kind" => "Deployment",
      ...>    "metadata" => %{
      ...>      "labels" => %{
      ...>        "app" => "nginx"
      ...>      },
      ...>      "name" => "nginx",
      ...>      "namespace" => "test"
      ...>    },
      ...>    "spec" => %{
      ...>      "replicas" => 2,
      ...>      "selector" => %{
      ...>        "matchLabels" => %{
      ...>          "app" => "nginx"
      ...>        }
      ...>      },
      ...>      "template" => %{
      ...>        "metadata" => %{
      ...>          "labels" => %{
      ...>            "app" => "nginx"
      ...>          }
      ...>        },
      ...>        "spec" => %{
      ...>          "containers" => %{
      ...>            "image" => "nginx",
      ...>            "name" => "nginx"
      ...>          }
      ...>        }
      ...>      }
      ...>    }
      ...>  }
      ...> K8s.Client.apply(deployment, &K8s.Client.run(&1, :default))

  """
  @spec apply(map(), Conn.t()) :: Base.result_t()
  def apply(resource, %Conn{} = conn) do
    case resource |> Imperative.get() |> Base.run(conn) do
      {:error, :not_found} ->
        resource
        |> add_last_applied_configuration()
        |> Imperative.create()
        |> Base.run(conn)

      {:ok, current_resource} ->
        last_applied_configuration = get_last_applied_configuration(current_resource)
        resource_configuration = get_last_applied_configuration(resource)

        if last_applied_configuration != resource_configuration do
          resource
          |> add_last_applied_configuration()
          |> Imperative.patch()
          |> Base.run(conn)
        end
    end
  end

  @spec add_last_applied_configuration(map) :: map
  defp add_last_applied_configuration(resource) do
    put_in(resource, ["metadata", Access.key("annotations", %{}), @last_applied_configuration_annotation], Jason.encode!(resource))
  end

  @spec get_last_applied_configuration(map) :: binary
  defp get_last_applied_configuration(resource) do
    get_in(resource, ["metadata", "annotations", @last_applied_configuration_annotation])
  end
end
