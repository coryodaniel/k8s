defmodule K8s.Test.KubeHelper do
  @moduledoc "Kubernetes helpers for test suite"

  @doc "Kubernetes Namespace manifest"
  @spec make_namespace(binary) :: map
  def make_namespace(name) do
    %{
      "apiVersion" => "v1",
      "metadata" => %{"name" => name},
      "kind" => "Namespace"
    }
  end

  @doc "Kubernetes Service manifest stub"
  @spec make_service(binary, binary | nil) :: map
  def make_service(name, ns \\ "default") do
    %{
      "kind" => "Service",
      "apiVersion" => "v1",
      "metadata" => %{"name" => name, "namespace" => ns}
    }
  end

  @doc "Kubernetes list manifest stub"
  @spec make_list(list, binary | nil) :: map
  def make_list(items, continue \\ "") do
    %{
      "metadata" => %{"continue" => continue},
      "items" => items
    }
  end
end
