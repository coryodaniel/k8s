defmodule K8s.Cluster.Group.ResourceNaming do
  @moduledoc false

  @doc """
  Rules for matching various name/kind inputs against a resource manifest.

  ## Examples
      Supports atom inputs
      iex> K8s.Cluster.Group.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments"}, :deployment)
      true

      Supports singular form match on `"kind"`
      iex> K8s.Cluster.Group.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments"}, "Deployment")
      true

      Supports case insensitive match on `"name"`
      iex> K8s.Cluster.Group.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments"}, "Deployments")
      true

      Supports matching subresources
      iex> K8s.Cluster.Group.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments/status"}, "deployments/status")
      true

      Supports matching subresources
      iex> K8s.Cluster.Group.ResourceNaming.matches?(%{"kind" => "Scale", "name" => "deployments/scale"}, "deployments/scale")
      true

      Does not select subresources when `"kind"` matches
      iex> K8s.Cluster.Group.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments/status"}, :deployment)
      false

      Does not select subresources when `"kind"` matches
      iex> K8s.Cluster.Group.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments/status"}, "Deployment")
      false

      Does not select subresources when `"kind"` matches
      iex> K8s.Cluster.Group.ResourceNaming.matches?(%{"kind" => "Deployment", "name" => "deployments/status"}, "Deployments")
      false

  """
  @spec matches?(map(), binary() | atom()) :: boolean()
  def matches?(resource, arg) when is_atom(arg), do: matches?(resource, Atom.to_string(arg))

  def matches?(resource, arg) when is_binary(arg) do
    is_exact_name_match?(resource, arg) ||
      is_exact_kind_match?(resource, arg) ||
      is_downcased_kind_match?(resource, arg) ||
      is_capitalized_name_match?(resource, arg) ||
      no_match(resource, arg)
  end

  defp is_exact_name_match?(%{"name" => name}, input), do: name == input

  defp is_exact_kind_match?(%{"kind" => kind, "name" => name}, input) do
    kind == input && !is_subresource_name?(name)
  end

  defp is_downcased_kind_match?(%{"kind" => kind, "name" => name}, input),
    do: String.downcase(kind) == input && !is_subresource_name?(name)

  defp is_capitalized_name_match?(%{"name" => name}, input), do: String.downcase(input) == name

  defp no_match(_, _), do: false

  @spec is_subresource_name?(binary()) :: boolean()
  def is_subresource_name?(name), do: String.contains?(name, "/")
end
