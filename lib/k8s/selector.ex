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
      ...> |> K8s.Selector.label_not({"foo", "bar"})
      ...> |> K8s.Selector.label_in({"tier", "cache"})
      ...> |> K8s.Selector.label_not_in({"environment", "dev"})
      ...> |> K8s.Selector.label_exists("foo")
      ...> |> K8s.Selector.label_does_not_exist("bar")
      %K8s.Selector{
        match_labels: %{"component" => {"=", "redis"}, "foo" => {"!=", "bar"}},
        match_expressions: [
          %{"key" => "bar", "operator" => "DoesNotExist"},
          %{"key" => "foo", "operator" => "Exists"},
          %{"key" => "environment", "operator" => "NotIn", "values" => ["dev"]},
          %{"key" => "tier", "operator" => "In", "values" => ["cache"]}
        ]
      }

    Provides a composable interface for adding selectors to `K8s.Operation`s.

      iex> K8s.Client.get("v1", :pods)
      ...> |> K8s.Selector.label({"app", "nginx"})
      ...> |> K8s.Selector.label_not(%{"tier" => "backend"})
      ...> |> K8s.Selector.label_in({"environment", ["qa", "prod"]})
      %K8s.Operation{data: nil, api_version: "v1", query_params: [labelSelector: %K8s.Selector{match_expressions: [%{"key" => "environment", "operator" => "In", "values" => ["qa", "prod"]}], match_labels: %{"app" => {"=", "nginx"}, "tier" => {"!=", "backend"}}}], method: :get, name: :pods, path_params: [], verb: :get}
  """

  alias K8s.{Operation, Resource}

  @type t :: %__MODULE__{
          match_labels: map(),
          match_fields: map(),
          match_expressions: list(map())
        }
  @type selector_or_operation_t :: t() | Operation.t()
  defstruct match_labels: %{}, match_fields: %{}, match_expressions: []

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
  `fieldSelector` helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.field({"metadata.namespace", "default"})
      %K8s.Selector{match_fields: %{"metadata.namespace" => {"=", "default"}}}

      iex> K8s.Selector.field(%{"metadata.namespace" => "default", "status.phase" => "Running"})
      %K8s.Selector{match_fields: %{"metadata.namespace" => {"=", "default"}, "status.phase" => {"=", "Running"}}}
  """

  @spec field({binary | atom, binary} | map) :: t()
  def field(fields),
    do: field(%K8s.Selector{}, fields)

  @spec field(selector_or_operation_t(), {binary | atom, binary} | map) ::
          selector_or_operation_t()
  def field(%{} = selector_or_operation, fields) do
    do_add_selector(selector_or_operation, :match_fields, fields, "=")
  end

  @doc """
  `fieldSelector` helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.field_not({"metadata.namespace", "default"})
      %K8s.Selector{match_fields: %{"metadata.namespace" => {"!=", "default"}}}

      iex> K8s.Selector.field(%{"metadata.namespace" => "default", "status.phase" => "Running"})
      %K8s.Selector{match_fields: %{"metadata.namespace" => {"=", "default"}, "status.phase" => {"=", "Running"}}}
  """

  @spec field_not({binary | atom, binary} | map) :: t()
  def field_not(fields) do
    field_not(%K8s.Selector{}, fields)
  end

  @spec field_not(selector_or_operation_t(), {binary | atom, binary}) :: selector_or_operation_t()
  def field_not(%{} = selector_or_operation, fields) do
    do_add_selector(selector_or_operation, :match_fields, fields, "!=")
  end

  @doc """
  `matchLabels` helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label({"component", "redis"})
      %K8s.Selector{match_labels: %{"component" => {"=", "redis"}}}

      iex> K8s.Selector.label(%{"component" => "redis", "env" => "prod"})
      %K8s.Selector{match_labels: %{"component" => {"=", "redis"}, "env" => {"=", "prod"}}}
  """

  @spec label({binary | atom, binary} | map) :: t()
  def label(labels), do: label(%K8s.Selector{}, labels)

  @doc """
  `matchLabels` helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label({"component", "redis"})
      ...> |> K8s.Selector.label({"environment", "dev"})
      %K8s.Selector{match_labels: %{"component" => {"=", "redis"}, "environment" => {"=", "dev"}}}
  """
  @spec label(selector_or_operation_t, {binary | atom, binary} | map) :: selector_or_operation_t()

  def label(%{} = selector_or_operation, labels),
    do: do_add_selector(selector_or_operation, :match_labels, labels, "=")

  @doc """
  `matchLabels` helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label_not({"component", "redis"})
      %K8s.Selector{match_labels: %{"component" => {"!=", "redis"}}}

      iex> K8s.Selector.label_not(%{"component" => "redis", "env" => "prod"})
      %K8s.Selector{match_labels: %{"component" => {"!=", "redis"}, "env" => {"!=", "prod"}}}
  """

  @spec label_not({binary | atom, binary} | map) :: t()
  def label_not(labels), do: label_not(%K8s.Selector{}, labels)

  @doc """
  `matchLabels` helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label_not({"component", "redis"})
      ...> |> K8s.Selector.label_not({"environment", "dev"})
      %K8s.Selector{match_labels: %{"component" => {"!=", "redis"}, "environment" => {"!=", "dev"}}}
  """
  @spec label_not(selector_or_operation_t, {binary | atom, binary} | map) ::
          selector_or_operation_t()

  def label_not(%{} = selector_or_operation, labels),
    do: do_add_selector(selector_or_operation, :match_labels, labels, "!=")

  @doc """
  `In` expression helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label_in({"component", "redis"})
      %K8s.Selector{match_expressions: [%{"key" => "component", "operator" => "In", "values" => ["redis"]}]}
  """
  @spec label_in({binary, binary | list(binary())}) :: t()
  def label_in(expr),
    do: label_in(%K8s.Selector{}, expr)

  @spec label_in(selector_or_operation_t, {binary, binary | list(binary())}) ::
          selector_or_operation_t()
  def label_in(%{} = selector_or_operation, {key, values}) do
    do_add_match_expression(selector_or_operation, %{
      "operator" => "In",
      "values" => List.wrap(values),
      "key" => key
    })
  end

  @doc """
  `NotIn` expression helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label_not_in({"component", "redis"})
      %K8s.Selector{match_expressions: [%{"key" => "component", "operator" => "NotIn", "values" => ["redis"]}]}
  """
  @spec label_not_in({binary, binary | list(binary())}) :: t()
  def label_not_in(expr),
    do: label_not_in(%K8s.Selector{}, expr)

  @spec label_not_in(selector_or_operation_t, {binary, binary | list(binary())}) ::
          selector_or_operation_t()
  def label_not_in(%{} = selector_or_operation, {key, values}) do
    do_add_match_expression(selector_or_operation, %{
      "operator" => "NotIn",
      "values" => List.wrap(values),
      "key" => key
    })
  end

  @doc """
  `Exists` expression helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label_exists("environment")
      %K8s.Selector{match_expressions: [%{"key" => "environment", "operator" => "Exists"}]}
  """
  @spec label_exists(binary) :: t()
  def label_exists(key),
    do: label_exists(%K8s.Selector{}, key)

  @spec label_exists(selector_or_operation_t, binary) :: selector_or_operation_t()
  def label_exists(%{} = selector_or_operation, key) do
    do_add_match_expression(selector_or_operation, %{"operator" => "Exists", "key" => key})
  end

  @doc """
  `DoesNotExist` expression helper that creates a composable `K8s.Selector`.

  ## Examples
      iex> K8s.Selector.label_does_not_exist("environment")
      %K8s.Selector{match_expressions: [%{"key" => "environment", "operator" => "DoesNotExist"}]}
  """
  @spec label_does_not_exist(binary) :: t()
  def label_does_not_exist(key),
    do: label_does_not_exist(%K8s.Selector{}, key)

  @spec label_does_not_exist(selector_or_operation_t, binary) :: selector_or_operation_t()
  def label_does_not_exist(%{} = selector_or_operation, key) do
    do_add_match_expression(selector_or_operation, %{"operator" => "DoesNotExist", "key" => key})
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
    selectors = serialize_match(labels) ++ serialize_match_expressions(expr)
    Enum.join(selectors, ",")
  end

  @doc """
  Serializes a `K8s.Selector` to a `labelSelector` query string.

  ## Examples

      iex> selector = K8s.Selector.label({"component", "redis"})
      ...> K8s.Selector.labels_to_s(selector)
      "component=redis"
  """
  @spec labels_to_s(t) :: binary()
  def labels_to_s(%K8s.Selector{match_labels: labels, match_expressions: expr}) do
    selectors = serialize_match(labels) ++ serialize_match_expressions(expr)
    Enum.join(selectors, ",")
  end

  @doc """
  Serializes a `K8s.Selector` to a `fieldSelector` query string.

  ## Examples

      iex> selector = K8s.Selector.field({"status.phase", "Running"})
      ...> K8s.Selector.fields_to_s(selector)
      "status.phase=Running"
  """
  @spec fields_to_s(t) :: binary()
  def fields_to_s(%K8s.Selector{match_fields: fields}) do
    fields
    |> serialize_match()
    |> Enum.join(",")
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

  @deprecated "Use serialize_match/1"
  defdelegate serialize_match_labels(labels), to: __MODULE__, as: :serialize_match

  @doc """
  Returns a `fieldSelector` query string value for a set of field selectors.

  ## Examples
    Builds a query string for a single field (`kubectl get pods --field-selector status.phase=Running`):

      iex> K8s.Selector.serialize_match(%{"status.phase" => {"=", "Running"}})
      ["status.phase=Running"]

    Builds a query string for multiple fields (`kubectl get pods --field-selector status.phase=Running,metadata.namespace!=default`):

      iex> K8s.Selector.serialize_match(%{"metadata.namespace" => {"!=", "default"}, "status.phase" => {"=", "Running"}})
      ["metadata.namespace!=default", "status.phase=Running"]
  """
  @spec serialize_match(map()) :: list(binary())
  def serialize_match(%{} = fields) do
    Enum.map(fields, fn
      {k, {op, v}} -> "#{k}#{op}#{v}"
      {k, v} -> "#{k}=#{v}"
    end)
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

  @spec aggregate_selectors(t(), atom(), {binary(), binary()} | map(), binary()) :: t()
  defp aggregate_selectors(selector, key, fields, op) do
    for field <- fields, reduce: selector do
      acc -> do_add_selector(acc, key, field, op)
    end
  end

  @spec do_add_selector(K8s.Operation.t(), atom(), {binary(), binary()} | map(), binary()) ::
          K8s.Operation.t()
  defp do_add_selector(%K8s.Operation{} = operation, key, fields, op) do
    selector =
      operation
      |> Operation.get_selector()
      |> do_add_selector(key, fields, op)

    Operation.put_selector(operation, selector)
  end

  @spec do_add_selector(t(), atom(), map(), binary()) :: t()
  defp do_add_selector(%__MODULE__{} = selector, key, fields, op) when is_map(fields) do
    aggregate_selectors(selector, key, fields, op)
  end

  @spec do_add_selector(t(), atom(), {binary(), binary()}, binary()) :: t()
  defp do_add_selector(%__MODULE__{} = selector, key, {k, v}, op) do
    current = Map.fetch!(selector, key)
    %{selector | key => Map.put(current, k, {op, v})}
  end

  @spec do_add_match_expression(K8s.Operation.t(), map()) :: K8s.Operation.t()
  defp do_add_match_expression(%K8s.Operation{} = operation, expression) do
    selector =
      operation
      |> Operation.get_selector()
      |> do_add_match_expression(expression)

    Operation.put_selector(operation, selector)
  end

  @spec do_add_match_expression(t(), map()) :: t()
  defp do_add_match_expression(selector, expression) do
    %{selector | match_expressions: [expression | selector.match_expressions]}
  end
end
