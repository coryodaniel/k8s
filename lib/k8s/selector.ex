defmodule K8s.Selector do
  @moduledoc """
  Builds [label selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) and [field selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/field-selectors/) for `K8s.Operation`s

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
      ...> |> K8s.Selector.label(%{"tier" => "backend"})
      ...> |> K8s.Selector.label_in({"environment", ["qa", "prod"]})
      %K8s.Operation{data: nil, api_version: "v1", query_params: [labelSelector: %K8s.Selector{match_expressions: [%{"key" => "environment", "operator" => "In", "values" => ["qa", "prod"]}], match_labels: %{"app" => "nginx", "tier" => "backend"}}], method: :get, name: :pods, path_params: [], verb: :get}
  """

  alias K8s.{Operation, Resource}

  @type t :: %__MODULE__{
          match_labels: map(),
          match_expressions: list(map())
        }
  @type selector_or_operation_t :: t() | Operation.t()
  defstruct match_labels: %{}, match_expressions: []

  @doc """
  Checks if a `K8s.Resource` matches all `matchLabels` using a logcal `AND`

  ## Examples
    Accepts `K8s.Selector`s:
      iex> labels = %{"env" => "prod", "tier" => "frontend"}
      ...> selector = %K8s.Selector{match_labels: labels}
      ...> resource = K8s.Resource.build("v1", "Pod", "default", "test", labels)
      ...> K8s.Selector.match_labels?(resource, selector)
      true

    Accepts maps:
      iex> labels = %{"env" => "prod", "tier" => "frontend"}
      ...> resource = K8s.Resource.build("v1", "Pod", "default", "test", labels)
      ...> K8s.Selector.match_labels?(resource, labels)
      true

    Returns `false` when not matching all labels:
      iex> not_a_match = %{"env" => "prod", "tier" => "frontend", "nope" => "not-a-match"}
      ...> resource = K8s.Resource.build("v1", "Pod", "default", "test", %{"env" => "prod", "tier" => "frontend"})
      ...> K8s.Selector.match_labels?(resource, not_a_match)
      false
  """
  @spec match_labels?(map, map | t) :: boolean
  def match_labels?(resource, %K8s.Selector{match_labels: labels}),
    do: match_labels?(resource, labels)

  def match_labels?(resource, %{} = labels) do
    Enum.all?(labels, fn {k, v} -> match_label?(resource, k, v) end)
  end

  @doc "Checks if a `K8s.Resource` matches a single label"
  @spec match_label?(map, binary, binary) :: boolean
  def match_label?(resource, key, value) do
    label = Resource.label(resource, key)
    label == value
  end

  @doc """
  Checks if a `K8s.Resource` matches all `matchExpressions` using a logical `AND`

  ## Examples
    Accepts `K8s.Selector`s:
      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "prod", "tier" => "frontend"}}}
      ...> expr1 = %{"operator" => "In", "key" => "env", "values" => ["prod", "qa"]}
      ...> expr2 = %{"operator" => "Exists", "key" => "tier"}
      ...> selector = %K8s.Selector{match_expressions: [expr1, expr2]}
      ...> K8s.Selector.match_expressions?(resource, selector)
      true

    Accepts `map`s:

      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "prod", "tier" => "frontend"}}}
      ...> expr1 = %{"operator" => "In", "key" => "env", "values" => ["prod", "qa"]}
      ...> expr2 = %{"operator" => "Exists", "key" => "tier"}
      ...> K8s.Selector.match_expressions?(resource, [expr1, expr2])
      true

    Returns `false` when not matching all expressions:

      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "prod", "tier" => "frontend"}}}
      ...> expr1 = %{"operator" => "In", "key" => "env", "values" => ["prod", "qa"]}
      ...> expr2 = %{"operator" => "Exists", "key" => "foo"}
      ...> K8s.Selector.match_expressions?(resource, [expr1, expr2])
      false
  """
  @spec match_expressions?(map, list(map) | t) :: boolean
  def match_expressions?(resource, %K8s.Selector{match_expressions: exprs}),
    do: match_expressions?(resource, exprs)

  def match_expressions?(resource, exprs) do
    Enum.all?(exprs, fn expr -> match_expression?(resource, expr) end)
  end

  @doc """
  Checks whether a resource matches a single selector `matchExpressions`

  ## Examples
    When an `In` expression matches
      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "prod"}}}
      ...> expr = %{"operator" => "In", "key" => "env", "values" => ["prod", "qa"]}
      ...> K8s.Selector.match_expression?(resource, expr)
      true

    When an `In` expression doesnt match
      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "In", "key" => "env", "values" => ["prod", "qa"]}
      ...> K8s.Selector.match_expression?(resource, expr)
      false

    When an `NotIn` expression matches
      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "NotIn", "key" => "env", "values" => ["prod"]}
      ...> K8s.Selector.match_expression?(resource, expr)
      true

    When an `NotIn` expression doesnt match
      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "NotIn", "key" => "env", "values" => ["dev"]}
      ...> K8s.Selector.match_expression?(resource, expr)
      false

    When an `Exists` expression matches
      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "Exists", "key" => "env"}
      ...> K8s.Selector.match_expression?(resource, expr)
      true

    When an `Exists` expression doesnt match
      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "Exists", "key" => "tier"}
      ...> K8s.Selector.match_expression?(resource, expr)
      false

    When an `DoesNotExist` expression matches
      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "DoesNotExist", "key" => "tier"}
      ...> K8s.Selector.match_expression?(resource, expr)
      true

    When an `DoesNotExist` expression doesnt match
      iex> resource = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "DoesNotExist", "key" => "env"}
      ...> K8s.Selector.match_expression?(resource, expr)
      false
  """
  @spec match_expression?(map(), map()) :: boolean()
  def match_expression?(resource, %{"operator" => "In", "key" => k, "values" => v}) do
    label = Resource.label(resource, k)
    Enum.member?(v, label)
  end

  def match_expression?(resource, %{"operator" => "NotIn", "key" => k, "values" => v}) do
    label = Resource.label(resource, k)
    !Enum.member?(v, label)
  end

  def match_expression?(resource, %{"operator" => "Exists", "key" => k}) do
    Resource.has_label?(resource, k)
  end

  def match_expression?(resource, %{"operator" => "DoesNotExist", "key" => k}) do
    !Resource.has_label?(resource, k)
  end

  def match_expression?(_, _), do: false

  @doc """
  `matchLabels` helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label({"component", "redis"})
      %K8s.Selector{match_labels: %{"component" => "redis"}}

      iex> K8s.Selector.label(%{"component" => "redis", "env" => "prod"})
      %K8s.Selector{match_labels: %{"component" => "redis", "env" => "prod"}}
  """
  @spec label({binary | atom, binary} | map) :: t()
  def label({key, value}), do: %K8s.Selector{match_labels: %{key => value}}
  def label(labels) when is_map(labels), do: %K8s.Selector{match_labels: labels}

  @doc """
  `matchLabels` helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> selector = K8s.Selector.label({"component", "redis"})
      ...> K8s.Selector.label(selector, {"environment", "dev"})
      %K8s.Selector{match_labels: %{"component" => "redis", "environment" => "dev"}}
  """
  @spec label(selector_or_operation_t, {binary | atom, binary} | map) :: selector_or_operation_t()
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

  @spec label_in(selector_or_operation_t, {binary, binary | list(binary())}) ::
          selector_or_operation_t()
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

  @spec label_not_in(selector_or_operation_t, {binary, binary | list(binary())}) ::
          selector_or_operation_t()
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

  @spec label_exists(selector_or_operation_t, binary) :: selector_or_operation_t()
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

  @spec label_does_not_exist(selector_or_operation_t, binary) :: selector_or_operation_t()
  def label_does_not_exist(%{} = selector_or_operation, key),
    do: merge(selector_or_operation, label_does_not_exist(key))

  @spec merge(selector_or_operation_t, t) :: selector_or_operation_t
  defp merge(%Operation{} = op, %__MODULE__{} = next) do
    prev = Operation.get_label_selector(op)
    merged_selector = merge(prev, next)
    Operation.put_label_selector(op, merged_selector)
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

  @spec do_serialize_match_expressions(list, list) :: list
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
