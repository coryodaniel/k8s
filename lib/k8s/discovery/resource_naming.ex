defmodule K8s.Discovery.ResourceNaming do
  @moduledoc false

  @doc """
  Rules for matching various name/kind inputs against a resource manifest.

  ## Examples
      Supports atom inputs
      iex> K8s.Discovery.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments"}, :deployment)
      true

      Supports singular form match on `"kind"`
      iex> K8s.Discovery.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments"}, "Deployment")
      true

      Supports case insensitive match on `"name"`
      iex> K8s.Discovery.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments"}, "Deployments")
      true

      Supports matching tuples of `{resource, subresource}` kind
      iex> K8s.Discovery.ResourceNaming.matches?(%{"kind" => "Eviction", "name" => "pods/eviction"}, {"Pod", "Eviction"})
      true

      Supports matching tuples of `{resource, subresource}` kind
      iex> K8s.Discovery.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments/status"}, {"Deployment", "Status"})
      true

      Supports matching subresources
      iex> K8s.Discovery.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments/status"}, "deployments/status")
      true

      Supports matching subresources
      iex> K8s.Discovery.ResourceNaming.matches?(%{"kind" => "Scale", "name" => "deployments/scale"}, "deployments/scale")
      true

      Does not select subresources when `"kind"` matches
      iex> K8s.Discovery.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments/status"}, :deployment)
      false

      Does not select subresources when `"kind"` matches
      iex> K8s.Discovery.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments/status"}, "Deployment")
      false

      Does not select subresources when `"kind"` matches
      iex> K8s.Discovery.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments/status"}, "Deployments")
      false

  """
  @spec matches?(map(), K8s.Operation.name_t()) :: boolean()
  def matches?(resource, arg) when is_atom(arg), do: matches?(resource, Atom.to_string(arg))

  def matches?(resource, arg) when is_binary(arg) do
    exact_name_match?(resource, arg) ||
      exact_kind_match?(resource, arg) ||
      downcased_kind_match?(resource, arg) ||
      capitalized_name_match?(resource, arg) ||
      no_match(resource, arg)
  end

  # This is not the best match. Its not checking pluralization of the `kind`, so could lead to conflicts
  # for similarly named resources that have the same types of applicable subresources.
  def matches?(%{"kind" => subkind, "name" => name} = _subresource, {kind, subkind}) do
    resource_kind_as_nameish = String.downcase(kind)
    String.starts_with?(name, resource_kind_as_nameish)
  end

  def matches?(%{"kind" => kind, "name" => name} = _subresource, {kind, subkind}) do
    subkind_as_nameish = String.downcase(subkind)
    String.ends_with?(name, "/" <> subkind_as_nameish)
  end

  def matches?(_map, {_kind, _subkind}), do: false

  @spec exact_name_match?(map, binary) :: boolean
  defp exact_name_match?(%{"name" => name}, input), do: name == input

  @spec exact_kind_match?(map, binary) :: boolean
  defp exact_kind_match?(%{"kind" => kind, "name" => name}, input) do
    kind == input && !subresource_name?(name)
  end

  @spec downcased_kind_match?(map, binary) :: boolean
  defp downcased_kind_match?(%{"kind" => kind, "name" => name}, input),
    do: String.downcase(kind) == input && !subresource_name?(name)

  @spec capitalized_name_match?(map, binary) :: boolean
  defp capitalized_name_match?(%{"name" => name}, input), do: String.downcase(input) == name

  @spec no_match(any, any) :: false
  defp no_match(_, _), do: false

  @spec subresource_name?(binary()) :: boolean()
  def subresource_name?(name), do: String.contains?(name, "/")
end
