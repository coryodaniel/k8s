defmodule K8s.Version do
  @moduledoc """
  Kubernetes [API Versioning](https://kubernetes.io/docs/concepts/overview/kubernetes-api/#api-versioning)
  """
  alias K8s.Version

  @type t :: %__MODULE__{major: pos_integer, minor: binary, patch: pos_integer}
  defstruct [:major, :minor, :patch]

  @pattern ~r/v(?<major>\d{1,})(?<minor>(alpha|beta)?)(?<patch>\d{0,})/

  @doc """
  Returns the recommended version from a list of versions.

  It will return the most stable version if any, otherwise the newest "*edge*" version.

  ## Examples

      iex> K8s.Version.recommended(["v1beta1", "v1", "v2"])
      "v2"

      iex> K8s.Version.recommended(["v1beta1", "v1"])
      "v1"

      iex> K8s.Version.recommended(["v1beta2", "v1beta1"])
      "v1beta2"

      iex> K8s.Version.recommended(["v1alpha1", "v1alpha2", "v1beta1"])
      "v1beta1"

  """
  @spec recommended(list(binary)) :: binary
  def recommended(versions) do
    versions
    |> parse_list
    |> sort
    |> List.first()
    |> serialize
  end

  @doc """
  Sorts a list of `K8s.Version`s

  ## Examples

      iex> raw_versions = Enum.shuffle(["v1", "v2beta1", "v2", "v1alpha1", "v1alpha2"])
      iex> versions = raw_versions |> Enum.map(&(K8s.Version.parse(&1)))
      iex> sorted_versions = versions |> K8s.Version.sort()
      iex> sorted_versions |> Enum.map(&(K8s.Version.serialize(&1)))
      ["v2", "v1", "v2beta1", "v1alpha2", "v1alpha1"]

  """
  @spec sort(list(t)) :: list(t)
  def sort(versions), do: Enum.sort(versions, &compare/2)

  @spec compare(t, t) :: boolean
  defp compare(%Version{minor: "stable", major: a}, %Version{minor: "stable", major: b}),
    do: a >= b

  defp compare(%Version{minor: "stable"}, _), do: true
  defp compare(_, %Version{minor: "stable"}), do: false

  defp compare(%Version{minor: "beta"}, %Version{minor: "alpha"}), do: true
  defp compare(%Version{minor: "alpha"}, %Version{minor: "beta"}), do: false

  # Guard here catches case where minor is the same and major is greater.
  # If using >= it will get a flakey result when everything is the same except patch level
  defp compare(%Version{minor: m, major: a}, %Version{minor: m, major: b}) when a > b, do: true

  defp compare(%Version{patch: a}, %Version{patch: b}), do: a >= b
  defp compare(_, _), do: false

  @doc """
  Returns only stable versions

  ## Examples

      iex> K8s.Version.serialize(%K8s.Version{major: 1, minor: "stable", patch: nil})
      "v1"

      iex> K8s.Version.serialize(%K8s.Version{major: 1, minor: "beta", patch: 1})
      "v1beta1"

      iex> K8s.Version.serialize(%K8s.Version{major: 1, minor: "alpha", patch: 1})
      "v1alpha1"

  """
  @spec serialize(Version.t()) :: binary
  def serialize(%Version{major: major, minor: "stable"}), do: "v#{major}"

  def serialize(%Version{major: major, minor: minor, patch: patch}),
    do: "v#{major}#{minor}#{patch}"

  @doc """
  Returns only stable versions

  ## Examples

      iex> K8s.Version.stable(["v1alpha1", "v1", "v2beta1"])
      [%K8s.Version{major: 1, minor: "stable", patch: nil}]

  """
  @spec stable(list(binary)) :: list(Version.t())
  def stable(versions), do: parse_filter(versions, "stable")

  @doc """
  Returns only alpha versions

  ## Examples

      iex> K8s.Version.alpha(["v1alpha1", "v1", "v2beta1"])
      [%K8s.Version{major: 1, minor: "alpha", patch: 1}]

  """
  @spec alpha(list(binary)) :: list(Version.t())
  def alpha(versions), do: parse_filter(versions, "alpha")

  @doc """
  Returns only beta versions

  ## Examples

      iex> K8s.Version.beta(["v1alpha1", "v1", "v2beta1"])
      [%K8s.Version{major: 2, minor: "beta", patch: 1}]

  """
  @spec beta(list(binary)) :: list(Version.t())
  def beta(versions), do: parse_filter(versions, "beta")

  @doc """
  Retuns all non-stable versions

  ## Examples

      iex> K8s.Version.edge(["v1alpha1", "v1", "v2beta1"])
      [%K8s.Version{major: 1, minor: "alpha", patch: 1}, %K8s.Version{major: 2, minor: "beta", patch: 1}]

  """
  @spec edge(list(binary)) :: list(Version.t())
  def edge(versions), do: alpha(versions) ++ beta(versions)

  @spec parse_filter(list(binary), binary) :: list(Version.t())
  defp parse_filter(versions, keep) do
    versions
    |> parse_list
    |> Enum.filter(&is(&1, keep))
  end

  @spec is(Version.t(), binary) :: boolean()
  defp is(%Version{minor: minor}, minor), do: true
  defp is(_, _), do: false

  @doc """
  Parses a Kubernetes API version into a `K8s.Version` struct

  ## Examples

      iex> K8s.Version.parse("v1")
      %K8s.Version{major: 1, minor: "stable", patch: nil}

      iex> K8s.Version.parse("v1beta2")
      %K8s.Version{major: 1, minor: "beta", patch: 2}

      iex> K8s.Version.parse("v1alpha1")
      %K8s.Version{major: 1, minor: "alpha", patch: 1}

  """
  @spec parse(binary()) :: Version.t()
  def parse(version) do
    %{"major" => major, "minor" => minor, "patch" => patch} =
      Regex.named_captures(@pattern, version)

    format(major, minor, patch)
  end

  @spec format(binary | integer, binary, binary | integer | nil) :: t
  defp format(major, "", "") when is_integer(major), do: format(major, "stable", nil)

  defp format(major, minor, patch) when is_binary(major),
    do: major |> String.to_integer() |> format(minor, patch)

  defp format(major, minor, patch) when is_binary(patch),
    do: format(major, minor, String.to_integer(patch))

  defp format(major, minor, patch), do: %__MODULE__{major: major, minor: minor, patch: patch}

  # Parse a list of string versions
  @spec parse_list(list(binary)) :: list(K8s.Version.t())
  defp parse_list(versions), do: parse_list(versions, [])
  @spec parse_list(list(binary), list(K8s.Version.t()) | nil) :: list(K8s.Version.t())
  defp parse_list([], acc), do: acc
  defp parse_list([version | tail], acc), do: parse_list(tail, [parse(version) | acc])
end
