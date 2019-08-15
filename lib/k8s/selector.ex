defmodule K8s.Selector do
  @moduledoc """
  Builds [label selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) for `K8s.Operation`s

  ## Examples
    Parse from a YAML map

      iex> deployment = %{
      ...>   "kind" => "Deployment",
      ...>   "metadata" => %{
      ...>     "name" => "nginx",
      ...>     "labels" => %{
      ...>       "app" => "nginx",
      ...>       "tier" => "backend"
      ...>     }
      ...>   },
      ...>   "spec" => %{
      ...>     "selector" => %{
      ...>       "matchLabels" => %{
      ...>         "app" => "nginx"
      ...>       }
      ...>     },
      ...>     "template" => %{
      ...>       "metadata" => %{
      ...>         "labels" => %{
      ...>           "app" => "nginx",
      ...>           "tier" => "backend"
      ...>         }
      ...>       }
      ...>     }
      ...>   }
      ...> }
      ...> K8s.Selector.parse(deployment)
      %K8s.Selector{match_labels: %{"app" => "nginx"}}

    Provides a composable interface for building label selectors

      iex> {"component", "redis"}
      ...> |> K8s.Selector.label()
      ...> |> K8s.Selector.label_in({"tier", "cache"})
      ...> |> K8s.Selector.label_not_in({"environment", "dev"})
      ...> |> K8s.Selector.label_exists("foo")
      ...> |> K8s.Selector.label_does_not_exist("bar")
      %K8s.Selector{
        match_labels: %{"component" => "redis"},
        match_expressions: [
          %{"key" => "tier", "operator" => "In", "values" => ["cache"]},
          %{"key" => "environment", "operator" => "NotIn", "values" => ["dev"]},
          %{"key" => "foo", "operator" => "Exists"},
          %{"key" => "bar", "operator" => "DoesNotExist"}
        ]
      }

    Provides a composable interface for adding selectors to `K8s.Operation`s.

      iex> K8s.Client.get("v1", :pods)
      ...> |> K8s.Selector.label({"app", "nginx"})
      ...> |> K8s.Selector.label_in({"environment", ["qa", "prod"]})
      %K8s.Operation{data: nil, api_version: "v1", label_selector: %K8s.Selector{match_expressions: [%{"key" => "environment", "operator" => "In", "values" => ["qa", "prod"]}], match_labels: %{"app" => "nginx"}}, method: :get, name: :pods, path_params: [], verb: :get}
  """

  @type t :: %__MODULE__{
          match_labels: map(),
          match_expressions: list(map())
        }
  @type selector_or_operation_t :: t() | K8s.Operation.t()
  defstruct match_labels: %{}, match_expressions: []

  @doc """
  `matchLabels` helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label({"component", "redis"})
      %K8s.Selector{match_labels: %{"component" => "redis"}}
  """
  @spec label({binary | atom, binary}) :: t()
  def label({key, value}), do: %K8s.Selector{match_labels: %{key => value}}

  @doc """
  `matchLabels` helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> selector = K8s.Selector.label({"component", "redis"})
      ...> K8s.Selector.label(selector, {"environment", "dev"})
      %K8s.Selector{match_labels: %{"component" => "redis", "environment" => "dev"}}
  """
  @spec label(selector_or_operation_t, {binary | atom, binary}) :: t()
  def label(%{} = selector_or_operation, label), do: merge(selector_or_operation, label(label))

  @doc """
  `In` expression helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label_in({"component", "redis"})
      %K8s.Selector{match_expressions: [%{"key" => "component", "operator" => "In", "values" => ["redis"]}]}
  """
  @spec label_in({binary, binary | list(binary())}) :: t()
  def label_in({key, values}) when is_binary(values), do: label_in({key, [values]})

  def label_in({key, values}),
    do: %K8s.Selector{
      match_expressions: [%{"operator" => "In", "values" => values, "key" => key}]
    }

  @spec label_in(selector_or_operation_t, {binary, binary | list(binary())}) :: t()
  def label_in(%{} = selector_or_operation, label),
    do: merge(selector_or_operation, label_in(label))

  @doc """
  `NotIn` expression helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label_not_in({"component", "redis"})
      %K8s.Selector{match_expressions: [%{"key" => "component", "operator" => "NotIn", "values" => ["redis"]}]}
  """
  @spec label_not_in({binary, binary | list(binary())}) :: t()
  def label_not_in({key, values}) when is_binary(values), do: label_not_in({key, [values]})

  def label_not_in({key, values}),
    do: %K8s.Selector{
      match_expressions: [%{"operator" => "NotIn", "values" => values, "key" => key}]
    }

  @spec label_not_in(selector_or_operation_t, {binary, binary | list(binary())}) :: t()
  def label_not_in(%{} = selector_or_operation, label),
    do: merge(selector_or_operation, label_not_in(label))

  @doc """
  `Exists` expression helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label_exists("environment")
      %K8s.Selector{match_expressions: [%{"key" => "environment", "operator" => "Exists"}]}
  """
  @spec label_exists(binary) :: t()
  def label_exists(key),
    do: %K8s.Selector{match_expressions: [%{"operator" => "Exists", "key" => key}]}

  @spec label_exists(selector_or_operation_t, binary) :: t()
  def label_exists(%{} = selector_or_operation, key),
    do: merge(selector_or_operation, label_exists(key))

  @doc """
  `DoesNotExist` expression helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label_does_not_exist("environment")
      %K8s.Selector{match_expressions: [%{"key" => "environment", "operator" => "DoesNotExist"}]}
  """
  @spec label_does_not_exist(binary) :: t()
  def label_does_not_exist(key),
    do: %K8s.Selector{match_expressions: [%{"operator" => "DoesNotExist", "key" => key}]}

  @spec label_does_not_exist(selector_or_operation_t, binary) :: t()
  def label_does_not_exist(%{} = selector_or_operation, key),
    do: merge(selector_or_operation, label_does_not_exist(key))

  @spec merge(t | K8s.Operation.t(), t) :: t
  defp merge(%K8s.Operation{} = op, %__MODULE__{} = next) do
    prev = op.label_selector || %__MODULE__{}
    %K8s.Operation{op | label_selector: merge(prev, next)}
  end

  defp merge(%__MODULE__{} = prev, %__MODULE__{} = next) do
    labels = Map.merge(prev.match_labels, next.match_labels)

    expressions =
      prev.match_expressions
      |> Enum.concat(next.match_expressions)
      |> Enum.uniq()

    %__MODULE__{match_labels: labels, match_expressions: expressions}
  end

  @doc """
  Serializes a `K8s.Selector` to a `labelSelector` query string.

  ## Examples

    iex> selector = K8s.Selector.label({"component", "redis"})
    ...> K8s.Selector.to_s(selector)
    "component=redis"
  """
  @spec to_s(t) :: binary()
  def to_s(%K8s.Selector{match_labels: labels, match_expressions: expr}) do
    selectors = serialize_match_labels(labels) ++ serialize_match_expressions(expr)
    Enum.join(selectors, ",")
  end

  @doc """
  Parses a `"selector"` map of `"matchLabels"` and `"matchExpressions"`

  ## Examples

    iex> selector = %{
    ...>   "matchLabels" => %{"component" => "redis"},
    ...>   "matchExpressions" => [
    ...>     %{"operator" => "In", "key" => "tier", "values" => ["cache"]},
    ...>     %{"operator" => "NotIn", "key" => "environment", "values" => ["dev"]}
    ...>   ]
    ...> }
    ...> K8s.Selector.parse(selector)
    %K8s.Selector{match_labels: %{"component" => "redis"}, match_expressions: [%{"operator" => "In", "key" => "tier", "values" => ["cache"]},%{"operator" => "NotIn", "key" => "environment", "values" => ["dev"]}]}
  """
  @spec parse(map) :: t
  def parse(%{"spec" => %{"selector" => selector}}), do: parse(selector)

  def parse(%{"matchLabels" => labels, "matchExpressions" => expressions}) do
    %K8s.Selector{
      match_labels: labels,
      match_expressions: expressions
    }
  end

  def parse(%{"matchLabels" => labels}), do: %K8s.Selector{match_labels: labels}

  def parse(%{"matchExpressions" => expressions}),
    do: %K8s.Selector{match_expressions: expressions}

  def parse(_), do: %__MODULE__{}

  @doc """
  Returns a `labelSelector` query string value for a set of label matches.

  ## Examples
    Builds a query string for a single label (`kubectl get pods -l environment=production`):

      iex> K8s.Selector.serialize_match_labels(%{"environment" => "prod"})
      ["environment=prod"]

    Builds a query string for multiple labels (`kubectl get pods -l environment=production,tier=frontend`):

      iex> K8s.Selector.serialize_match_labels(%{"environment" => "prod", "tier" => "frontend"})
      ["environment=prod", "tier=frontend"]
  """
  @spec serialize_match_labels(map()) :: list(binary())
  def serialize_match_labels(%{} = labels) do
    Enum.map(labels, fn {k, v} -> "#{k}=#{v}" end)
  end

  @doc """
  Returns a `labelSelector` query string value for a set of label expressions.

  For `!=` matches, use a `NotIn` set-based expression.

  ## Examples
    Builds a query string for `In` expressions (`kubectl get pods -l 'environment in (production,qa),tier in (frontend)`):

      iex> expressions = [
      ...>   %{"operator" => "In", "key" => "environment", "values" => ["production", "qa"]},
      ...>   %{"operator" => "In", "key" => "tier", "values" => ["frontend"]},
      ...> ]
      ...> K8s.Selector.serialize_match_expressions(expressions)
      ["environment in (production,qa)", "tier in (frontend)"]

    Builds a query string for `NotIn` expressions (`kubectl get pods -l 'environment notin (frontend)`):

      iex> expressions = [
      ...>   %{"operator" => "NotIn", "key" => "environment", "values" => ["frontend"]}
      ...> ]
      ...> K8s.Selector.serialize_match_expressions(expressions)
      ["environment notin (frontend)"]

    Builds a query string for `Exists` expressions (`kubectl get pods -l 'environment'`):

      iex> expressions = [
      ...>   %{"operator" => "Exists", "key" => "environment"}
      ...> ]
      ...> K8s.Selector.serialize_match_expressions(expressions)
      ["environment"]

    Builds a query string for `DoesNotExist` expressions (`kubectl get pods -l '!environment'`):

      iex> expressions = [
      ...>   %{"operator" => "DoesNotExist", "key" => "environment"}
      ...> ]
      ...> K8s.Selector.serialize_match_expressions(expressions)
      ["!environment"]
  """
  @spec serialize_match_expressions(list(map())) :: list(binary())
  def serialize_match_expressions(exps) do
    do_serialize_match_expressions(exps, [])
  end

  defp do_serialize_match_expressions([], acc), do: acc |> Enum.reverse()

  defp do_serialize_match_expressions([exp | tail], acc) do
    serialized_expression = serialize_match_expression(exp)
    do_serialize_match_expressions(tail, [serialized_expression | acc])
  end

  @spec serialize_match_expression(map()) :: binary()
  defp serialize_match_expression(%{"operator" => "In", "values" => values, "key" => key}) do
    vals = Enum.join(values, ",")
    "#{key} in (#{vals})"
  end

  defp serialize_match_expression(%{"operator" => "NotIn", "values" => values, "key" => key}) do
    vals = Enum.join(values, ",")
    "#{key} notin (#{vals})"
  end

  defp serialize_match_expression(%{"operator" => "Exists", "key" => key}), do: key

  defp serialize_match_expression(%{"operator" => "DoesNotExist", "key" => key}), do: "!#{key}"
end
