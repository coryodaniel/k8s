defmodule K8s.Resource do
  @moduledoc "Kubernetes manifest attribute helpers"

  @type yaml_elixir_error_t :: YamlElixir.FileNotFoundError.t() | YamlElixir.ParsingError.t()

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

  ## Examples

      iex> opts = [namespace: "default", name: "nginx", image: "nginx:nginx:1.7.9"]
      ...> K8s.Resource.from_file("test/support/deployment.yaml", opts)
      {:ok, %{
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
      }}
  """
  @spec from_file(binary, keyword | nil) :: {:ok, map} | {:error, :enoent | yaml_elixir_error_t}
  def from_file(filepath, assigns \\ []) do
    with {:ok, interpolated_template} <- render(filepath, assigns),
         {:ok, resource} <- YamlElixir.read_from_string(interpolated_template) do
      {:ok, resource}
    else
      error -> error
    end
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
  @spec from_file!(binary, keyword | nil) :: map | no_return
  def from_file!(path, assigns \\ []) do
    case from_file(path, assigns) do
      {:ok, resource} -> resource
      {:error, error} -> raise error
    end
  end

  @doc """
  Create a list of resource `Map`s from a YAML file containing a YAML stream.

  ## Examples

      iex> opts = [namespace: "default", name: "nginx", image: "nginx:nginx:1.7.9"]
      ...> K8s.Resource.all_from_file("test/support/helm-chart.yaml", opts)
      {:ok, [
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
      ]}
  """
  @spec all_from_file(binary, keyword) ::
          {:ok, list(map)} | {:error, :enoent | yaml_elixir_error_t}
  def all_from_file(filepath, assigns \\ []) do
    with {:ok, interpolated_template} <- render(filepath, assigns),
         {:ok, resources} <- YamlElixir.read_all_from_string(interpolated_template),
         no_empty_maps <- Enum.filter(resources, &(&1 != %{})) do
      {:ok, no_empty_maps}
    end
  end

  @doc """
  Create a list of resource `Map`s from a YAML file containing a YAML stream.

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
  def all_from_file!(path, assigns \\ []) do
    case all_from_file(path, assigns) do
      {:ok, resources} -> resources
      {:error, error} -> raise error
    end
  end

  @spec render(binary, keyword) :: {:ok, binary} | {:error, :enoent}
  defp render(filepath, assigns) do
    case File.read(filepath) do
      {:ok, template} ->
        rendered = EEx.eval_string(template, assigns)
        {:ok, rendered}

      {:error, reason} ->
        {:error,
         %File.Error{reason: reason, action: "read file", path: IO.chardata_to_string(filepath)}}
    end
  end
end
