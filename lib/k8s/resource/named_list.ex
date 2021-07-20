defmodule K8s.Resource.NamedList do
  @moduledoc """
  Provides an accessor to a list of maps whereas each element in the list has a key named "name". The name should
  be unique within the list and therefore defining the element.
  """

  @doc """
  Provides an accessor to a list of maps whereas each element in the list has a key named "name". If no such element
  exists within the given list, get_in() will return nil while updating will create an empty element with the given
  name.

  ## Examples
    iex> get_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access("key2"), "value"])
    "value2"

    iex> get_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access("key2")])
    %{"name" => "key2", "value" => "value2"}

    iex> get_in([%{"name" => "key1", "value" => "value1"}], [K8s.Resource.NamedList.access("missing-key"), "value"])
    nil

    iex> get_in([%{"name" => "key1", "value" => "value1"}], [K8s.Resource.NamedList.access("missing-key")])
    nil

    iex> put_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access("key1"), "value"], "value_new")
    [%{"name" => "key1", "value" => "value_new"}, %{"name" => "key2", "value" => "value2"}]

    iex> put_in([%{"name" => "key1", "value" => "value1"}], [K8s.Resource.NamedList.access("missing-key"), "value"], "value_new")
    [%{"name" => "missing-key", "value" => "value_new"}, %{"name" => "key1", "value" => "value1"}]

    iex> pop_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access("key1"), "value"])
    {"value1", [%{"name" => "key1"}, %{"name" => "key2", "value" => "value2"}]}

    iex> pop_in([%{"name" => "key1", "value" => "value1"}], [K8s.Resource.NamedList.access("missing-key"), "value"])
    {nil, [%{"name" => "missing-key"}, %{"name" => "key1", "value" => "value1"}]}

    iex> pop_in([%{"name" => "key1", "value" => "value1"}], [K8s.Resource.NamedList.access("missing-key")])
    {%{"name" => "missing-key"}, [%{"name" => "key1", "value" => "value1"}]}
  """
  @spec access(binary) :: Access.access_fun(data :: list(), get_value :: term)
  def access(name), do: create_accessor(name, raise: false)

  @doc """
  Provides an accessor to a list of maps whereas each element in the list has a key named "name". If no such element
  exists within the given list, an exception is raised.

  ## Examples
    iex> get_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access!("key2"), "value"])
    "value2"

    iex> get_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access!("key2")])
    %{"name" => "key2", "value" => "value2"}

    iex> get_in([%{"name" => "key1", "value" => "value1"}], [K8s.Resource.NamedList.access!("missing-key"), "value"])
    ** (ArgumentError) There is not item with name missing-key in the given named list.

    iex> get_in([%{"name" => "key1", "value" => "value1"}], [K8s.Resource.NamedList.access!("missing-key")])
    ** (ArgumentError) There is not item with name missing-key in the given named list.

    iex> put_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access!("key1"), "value"], "value_new")
    [%{"name" => "key1", "value" => "value_new"}, %{"name" => "key2", "value" => "value2"}]

    iex> put_in([%{"name" => "key1", "value" => "value1"}], [K8s.Resource.NamedList.access!("missing-key"), "value"], "value_new")
    ** (ArgumentError) There is not item with name missing-key in the given named list.

    iex> pop_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access!("key1"), "value"])
    {"value1", [%{"name" => "key1"}, %{"name" => "key2", "value" => "value2"}]}

    iex> pop_in([%{"name" => "key1", "value" => "value1"}], [K8s.Resource.NamedList.access!("missing-key"), "value"])
    ** (ArgumentError) There is not item with name missing-key in the given named list.

    iex> pop_in([%{"name" => "key1", "value" => "value1"}], [K8s.Resource.NamedList.access!("missing-key")])
    ** (ArgumentError) There is not item with name missing-key in the given named list.
  """
  @spec access!(binary) :: Access.access_fun(data :: list(), get_value :: term)
  def access!(name), do: create_accessor(name, raise: true)

  @spec create_accessor(binary, keyword) :: Access.access_fun(data :: list(), get_value :: term)
  defp create_accessor(name, opts) do
    fn op, data, next ->
      if Enum.count(data, match_name_callback(name)) > 1 do
        raise ArgumentError, "The name #{name} is not unique in the given list: #{inspect(data)}"
      end

      create_accessor(op, data, name, next, opts)
    end
  end

  @spec create_accessor(:get | :get_and_update, maybe_improper_list, term, function, keyword) ::
          any
  defp create_accessor(:get, data, name, next, opts) when is_list(data) do
    raise_if_key_does_not_exist = Keyword.get(opts, :raise, false)
    item = Enum.find(data, match_name_callback(name))

    if raise_if_key_does_not_exist && is_nil(item) do
      raise ArgumentError, "There is not item with name #{name} in the given named list."
    end

    next.(item)
  end

  defp create_accessor(:get_and_update, data, name, next, opts) when is_list(data) do
    {value, rest} =
      case Enum.find_index(data, match_name_callback(name)) do
        nil ->
          if Keyword.get(opts, :raise, false) do
            raise ArgumentError, "There is not item with name #{name} in the given named list."
          end

          {%{"name" => name}, data}

        index ->
          List.pop_at(data, index)
      end

    case next.(value) do
      {get, update} -> {get, [update | rest]}
      :pop -> {value, rest}
    end
  end

  defp create_accessor(_op, data, _name, _next, _opts) do
    raise ArgumentError,
          "Kubernetes.NamedList.access/1 expected a named list, got: #{inspect(data)}"
  end

  @spec match_name_callback(term) :: (nil | maybe_improper_list() | map() -> boolean())
  defp match_name_callback(name), do: &(&1["name"] == name)
end
