defmodule K8s.Resource.NamedList do
  @moduledoc """
  Provides an accessor to a list of maps whereas each element in the list has a key named "name". The name should
  be unique within the list and therefore defining the element.

  ## Examples

    iex> get_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access("key2"), "value"])
    "value2"

    iex> put_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access("key1"), "value"], "value_new")
    [%{"name" => "key1", "value" => "value_new"}, %{"name" => "key2", "value" => "value2"}]

    iex> pop_in([%{"name" => "key1", "value" => "value1"}, %{"name" => "key2", "value" => "value2"}], [K8s.Resource.NamedList.access("key1"), "value"])
    {"value1", [%{"name" => "key1"}, %{"name" => "key2", "value" => "value2"}]}
  """

  @spec access(binary) :: Access.access_fun(data :: list(), get_value :: term)
  def access(name) do
    fn op, data, next ->
      if Enum.count(data, match_name_callback(name)) > 1 do
        raise ArgumentError, "The name #{name} is not unique in the given list: #{inspect(data)}"
      end

      access(op, data, name, next)
    end
  end

  defp access(:get, data, name, next) when is_list(data) do
    data |> Enum.find(match_name_callback(name)) |> next.()
  end

  defp access(:get_and_update, data, name, next) when is_list(data) do
    index = Enum.find_index(data, match_name_callback(name))
    {value, rest} = List.pop_at(data, index)

    case next.(value) do
      {get, update} -> {get, [update | rest]}
      :pop -> {value, rest}
    end
  end

  defp access(_op, data, _name, _next) do
    raise ArgumentError,
          "Kubernetes.NamedList.access/1 expected a named list, got: #{inspect(data)}"
  end

  defp match_name_callback(name), do: &(&1["name"] == name)
end
