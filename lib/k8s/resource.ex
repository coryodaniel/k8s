defmodule K8s.Resource do
  @moduledoc """
  Manifest attribute helpers
  """

  defdelegate kind(resource), to: K8s.Resource.FieldAccessors
  defdelegate api_version(resource), to: K8s.Resource.FieldAccessors
  defdelegate metadata(resource), to: K8s.Resource.FieldAccessors
  defdelegate name(resource), to: K8s.Resource.FieldAccessors
  defdelegate namespace(resource), to: K8s.Resource.FieldAccessors
  defdelegate labels(resource), to: K8s.Resource.FieldAccessors
  defdelegate label(resource, name), to: K8s.Resource.FieldAccessors
  defdelegate annotations(resource), to: K8s.Resource.FieldAccessors
  defdelegate annotation(resource, name), to: K8s.Resource.FieldAccessors
  defdelegate has_label?(resource, name), to: K8s.Resource.FieldAccessors
  defdelegate has_annotation?(resource, name), to: K8s.Resource.FieldAccessors

  defdelegate cpu(value), to: K8s.Resource.Utilization
  defdelegate memory(value), to: K8s.Resource.Utilization

  @doc """
  Helper for building a kubernetes' resource `Map`

  ## Examples
      iex> K8s.Resource.build("v1", "Pod")
      %{"apiVersion" => "v1", "kind" => "Pod", "metadata" => %{}}

      iex> K8s.Resource.build("v1", "Namespace", "foo")
      %{"apiVersion" => "v1", "kind" => "Namespace", "metadata" => %{"name" => "foo"}}

      iex> K8s.Resource.build("v1", "Pod", "default", "foo")
      %{"apiVersion" => "v1", "kind" => "Pod", "metadata" => %{"namespace" => "default", "name" => "foo"}}
  """
  @spec build(binary(), binary()) :: map()
  def build(api_version, kind) do
    %{
      "apiVersion" => api_version,
      "kind" => kind,
      "metadata" => %{}
    }
  end

  @spec build(binary(), binary(), binary()) :: map()
  def build(api_version, kind, name) do
    api_version
    |> build(kind)
    |> put_in(["metadata", "name"], name)
  end

  @spec build(binary(), binary(), binary(), binary()) :: map()
  def build(api_version, kind, namespace, name) do
    api_version
    |> build(kind, name)
    |> put_in(["metadata", "namespace"], namespace)
  end

  @spec build(binary(), binary(), binary(), binary(), map()) :: map()
  def build(api_version, kind, namespace, name, %{} = labels) do
    api_version
    |> build(kind, name)
    |> put_in(["metadata", "namespace"], namespace)
    |> put_in(["metadata", "labels"], labels)
  end

  @doc """
  Create a resource `Map` from a YAML file.

  Raises `File.Error` when the file does not exist.

  ## Examples

      iex> opts = [namespace: "default", name: "nginx", image: "nginx:nginx:1.7.9"]
      ...> K8s.Resource.from_file!("test/support/deployment.yaml", opts)
      %{
        "apiVersion" => "apps/v1",
        "kind" => "Deployment",
        "metadata" => %{
          "labels" => %{"app" => "nginx"},
          "name" => "nginx-deployment",
          "namespace" => "default"
        },
        "spec" => %{
          "replicas" => 3,
          "selector" => %{"matchLabels" => %{"app" => "nginx"}},
          "template" => %{
            "metadata" => %{"labels" => %{"app" => "nginx"}},
            "spec" => %{
              "containers" => [
                %{
                  "image" => "nginx:nginx:1.7.9",
                  "name" => "nginx",
                  "ports" => [%{"containerPort" => 80}]
                }
              ]
            }
          }
        }
      }
  """
  @spec from_file!(String.t(), keyword()) :: map | no_return
  def from_file!(path, assigns) do
    path
    |> File.read!()
    |> EEx.eval_string(assigns)
    |> YamlElixir.read_from_string!()
  end

  @doc """
  Create a list of resource `Map`s from a YAML file with multi object annotation.

  Raises `File.Error` when the file does not exist.

  ## Examples

      iex> opts = [namespace: "default", name: "nginx", image: "nginx:nginx:1.7.9"]
      ...> K8s.Resource.all_from_file!("test/support/helm-chart.yaml", opts)
      [
        %{
          "apiVersion" => "v1",
          "kind" => "Namespace",
          "metadata" => %{"name" => "default"}
        },
        %{
          "apiVersion" => "apps/v1",
          "kind" => "Deployment",
          "metadata" => %{
            "labels" => %{"app" => "nginx"},
            "name" => "nginx-deployment",
            "namespace" => "default"
          },
          "spec" => %{
            "replicas" => 3,
            "selector" => %{"matchLabels" => %{"app" => "nginx"}},
            "template" => %{
              "metadata" => %{"labels" => %{"app" => "nginx"}},
              "spec" => %{
                "containers" => [
                  %{
                    "image" => "nginx:nginx:1.7.9",
                    "name" => "nginx",
                    "ports" => [%{"containerPort" => 80}]
                  }
                ]
              }
            }
          }
        }
      ]
  """
  @spec all_from_file!(String.t(), keyword()) :: list(map) | no_return
  def all_from_file!(path, assigns) do
    path
    |> File.read!()
    |> EEx.eval_string(assigns)
    |> YamlElixir.read_all_from_string!()
    |> Enum.filter(&(&1 != %{}))
  end
end
