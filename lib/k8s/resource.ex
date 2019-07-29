defmodule K8s.Resource do
  @moduledoc """
  Manifest attribute helpers
  """

  # Symbol -> bytes
  @binary_multipliers %{
    "Ki" => 1024,
    "Mi" => 1_048_576,
    "Gi" => 1_073_741_824,
    "Ti" => 1_099_511_627_776,
    "Pi" => 1_125_899_906_842_624,
    "Ei" => 1_152_921_504_606_846_976
  }

  @decimal_multipliers %{
    "" => 1,
    "k" => 1000,
    "m" => 1_000_000,
    "M" => 1_000_000,
    "G" => 1_000_000_000,
    "T" => 1_000_000_000_000,
    "P" => 1_000_000_000_000_000,
    "E" => 1_000_000_000_000_000_000
  }

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

  @doc """
  Returns the kind of k8s resource.

  ## Examples
      iex> K8s.Resource.kind(%{"kind" => "Deployment"})
      "Deployment"
  """
  @spec kind(map()) :: binary() | nil
  def kind(%{} = resource), do: resource["kind"]

  @doc """
  Returns the apiVersion of k8s resource.

  ## Examples
      iex> K8s.Resource.api_version(%{"apiVersion" => "apps/v1"})
      "apps/v1"
  """
  @spec api_version(map()) :: binary() | nil
  def api_version(%{} = resource), do: resource["apiVersion"]

  @doc """
  Returns the metadata of k8s resource.

  ## Examples
      iex> K8s.Resource.metadata(%{"metadata" => %{"name" => "nginx", "namespace" => "foo"}})
      %{"name" => "nginx", "namespace" => "foo"}
  """
  @spec metadata(map()) :: map() | nil
  def metadata(%{} = resource), do: resource["metadata"]

  @doc """
  Returns the name of k8s resource.

  ## Examples
      iex> K8s.Resource.name(%{"metadata" => %{"name" => "nginx", "namespace" => "foo"}})
      "nginx"
  """
  @spec name(map()) :: binary() | nil
  def name(%{} = resource), do: get_in(resource, ~w(metadata name))

  @doc """
  Returns the namespace of k8s resource.

  ## Examples
      iex> K8s.Resource.namespace(%{"metadata" => %{"name" => "nginx", "namespace" => "foo"}})
      "foo"
  """
  @spec namespace(map()) :: binary() | nil
  def namespace(%{} = resource), do: get_in(resource, ~w(metadata namespace))

  @doc """
  Returns the labels of k8s resource.

  ## Examples
      iex> K8s.Resource.labels(%{"metadata" => %{"labels" => %{"env" => "test"}}})
      %{"env" => "test"}
  """
  @spec labels(map()) :: map()
  def labels(%{} = resource), do: get_in(resource, ~w(metadata labels)) || %{}

  @doc """
  Returns the value of a k8s resource's label.

  ## Examples
      iex> K8s.Resource.label(%{"metadata" => %{"labels" => %{"env" => "test"}}}, "env")
      "test"
  """
  @spec label(map(), binary) :: binary() | nil
  def label(%{} = resource, name), do: get_in(resource, ["metadata", "labels", name])

  @doc """
  Returns the annotations of k8s resource.

  ## Examples
      iex> K8s.Resource.annotations(%{"metadata" => %{"annotations" => %{"env" => "test"}}})
      %{"env" => "test"}
  """
  @spec annotations(map()) :: map()
  def annotations(%{} = resource), do: get_in(resource, ~w(metadata annotations)) || %{}

  @doc """
  Returns the value of a k8s resource's annotation.

  ## Examples
      iex> K8s.Resource.annotation(%{"metadata" => %{"annotations" => %{"env" => "test"}}}, "env")
      "test"
  """
  @spec annotation(map(), binary) :: binary() | nil
  def annotation(%{} = resource, name), do: get_in(resource, ["metadata", "annotations", name])

  @doc """
  Check if a label is present.

  ## Examples
      iex> K8s.Resource.has_label?(%{"metadata" => %{"labels" => %{"env" => "test"}}}, "env")
      true

      iex> K8s.Resource.has_label?(%{"metadata" => %{"labels" => %{"env" => "test"}}}, "foo")
      false
  """
  @spec has_label?(map(), binary()) :: boolean()
  def has_label?(%{} = resource, name), do: resource |> labels() |> Map.has_key?(name)

  @doc """
  Check if an annotation is present.

  ## Examples
      iex> K8s.Resource.has_annotation?(%{"metadata" => %{"annotations" => %{"env" => "test"}}}, "env")
      true

      iex> K8s.Resource.has_annotation?(%{"metadata" => %{"annotations" => %{"env" => "test"}}}, "foo")
      false
  """
  @spec has_annotation?(map(), binary()) :: boolean()
  def has_annotation?(%{} = resource, name), do: resource |> annotations() |> Map.has_key?(name)

  @doc """
  Deserializes CPU quantity

  ## Examples
    Parses whole values
      iex> K8s.Resource.cpu("3")
      3

    Parses millicpu values
      iex> K8s.Resource.cpu("500m")
      0.5

    Parses decimal values
      iex> K8s.Resource.cpu("1.5")
      1.5

  """
  @spec cpu(binary()) :: number
  def cpu(nil), do: 0
  def cpu("-" <> str), do: -1 * deserialize_cpu_quantity(str)
  def cpu("+" <> str), do: deserialize_cpu_quantity(str)
  def cpu(str), do: deserialize_cpu_quantity(str)

  defp deserialize_cpu_quantity(str) do
    contains_decimal = String.contains?(str, ".")

    {value, maybe_millicpu} =
      case contains_decimal do
        true -> Float.parse(str)
        false -> Integer.parse(str)
      end

    case maybe_millicpu do
      "m" -> value / 1000
      _ -> value
    end
  end

  @doc """
  Deserializes memory quantity

  ## Examples
    Parses whole values
      iex> K8s.Resource.memory("1000000")
      1000000

    Parses decimal values
      iex> K8s.Resource.memory("10.75")
      10.75

    Parses decimalSI values
      iex> K8s.Resource.memory("10M")
      10000000

    Parses binarySI suffixes
      iex> K8s.Resource.memory("50Mi")
      52428800

    Returns the numeric value when the suffix is unrecognized
      iex> K8s.Resource.memory("50Foo")
      50

  """
  @spec memory(binary()) :: number
  def memory(nil), do: 0
  def memory("-" <> str), do: -1 * deserialize_memory_quantity(str)
  def memory("+" <> str), do: deserialize_memory_quantity(str)
  def memory(str), do: deserialize_memory_quantity(str)

  defp deserialize_memory_quantity(str) do
    contains_decimal = String.contains?(str, ".")
    # contains_exponent = String.match?(str, ~r/[eE]/)

    {value, maybe_multiplier} =
      case contains_decimal do
        true -> Float.parse(str)
        false -> Integer.parse(str)
      end

    multiplier = @binary_multipliers[maybe_multiplier] || @decimal_multipliers[maybe_multiplier]

    case multiplier do
      nil ->
        value

      mult ->
        value * mult
    end
  end
end
