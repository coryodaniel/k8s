defmodule K8s.Resource do
  @moduledoc """
  Manifest attribute helpers
  """

  @doc """
  Returns the kind of k8s resource.

  ## Examples
      iex> K8s.Resource.kind(%{"kind" => "Deployment"})
      "Deployment"
  """
  @spec kind(map()) :: binary() | nil
  def kind(resource = %{}), do: resource["kind"]

  @doc """
  Returns the metadata of k8s resource.

  ## Examples
      iex> K8s.Resource.metadata(%{"metadata" => %{"name" => "nginx", "namespace" => "foo"}})
      %{"name" => "nginx", "namespace" => "foo"}
  """
  @spec metadata(map()) :: map() | nil
  def metadata(resource = %{}), do: resource["metadata"]

  @doc """
  Returns the name of k8s resource.

  ## Examples
      iex> K8s.Resource.name(%{"metadata" => %{"name" => "nginx", "namespace" => "foo"}})
      "nginx"
  """
  @spec name(map()) :: binary() | nil
  def name(resource = %{}), do: get_in(resource, ~w(metadata name))

  @doc """
  Returns the namespace of k8s resource.

  ## Examples
      iex> K8s.Resource.namespace(%{"metadata" => %{"name" => "nginx", "namespace" => "foo"}})
      "foo"
  """
  @spec namespace(map()) :: binary() | nil
  def namespace(resource = %{}), do: get_in(resource, ~w(metadata namespace))

  @doc """
  Returns the labels of k8s resource.

  ## Examples
      iex> K8s.Resource.labels(%{"metadata" => %{"labels" => %{"env" => "test"}}})
      %{"env" => "test"}
  """
  @spec labels(map()) :: map()
  def labels(resource = %{}), do: get_in(resource, ~w(metadata labels)) || %{}

  @doc """
  Returns the value of a k8s resource's label.

  ## Examples
      iex> K8s.Resource.label(%{"metadata" => %{"labels" => %{"env" => "test"}}}, "env")
      "test"
  """
  @spec label(map(), binary) :: binary() | nil
  def label(resource = %{}, name), do: get_in(resource, ["metadata", "labels", name])

  @doc """
  Returns the annotations of k8s resource.

  ## Examples
      iex> K8s.Resource.annotations(%{"metadata" => %{"annotations" => %{"env" => "test"}}})
      %{"env" => "test"}
  """
  @spec annotations(map()) :: map()
  def annotations(resource = %{}), do: get_in(resource, ~w(metadata annotations)) || %{}

  @doc """
  Returns the value of a k8s resource's annotation.

  ## Examples
      iex> K8s.Resource.annotation(%{"metadata" => %{"annotations" => %{"env" => "test"}}}, "env")
      "test"
  """
  @spec annotation(map(), binary) :: binary() | nil
  def annotation(resource = %{}, name), do: get_in(resource, ["metadata", "annotations", name])

  @doc """
  Check if a label is present.

  ## Examples
      iex> K8s.Resource.has_label?(%{"metadata" => %{"labels" => %{"env" => "test"}}}, "env")
      true

      iex> K8s.Resource.has_label?(%{"metadata" => %{"labels" => %{"env" => "test"}}}, "foo")
      false
  """
  @spec has_label?(map(), binary()) :: boolean()
  def has_label?(resource = %{}, name), do: resource |> labels() |> Map.has_key?(name)

  @doc """
  Check if an annotation is present.

  ## Examples
      iex> K8s.Resource.has_annotation?(%{"metadata" => %{"annotations" => %{"env" => "test"}}}, "env")
      true

      iex> K8s.Resource.has_annotation?(%{"metadata" => %{"annotations" => %{"env" => "test"}}}, "foo")
      false
  """
  @spec has_annotation?(map(), binary()) :: boolean()
  def has_annotation?(resource = %{}, name), do: resource |> annotations() |> Map.has_key?(name)
end
