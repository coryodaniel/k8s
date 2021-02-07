defmodule K8s.Resource.NamedListTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest K8s.Resource.NamedList

  alias K8s.Resource.NamedList, as: MUT

  describe "access/1" do
    test "raises if name is not unique" do
      assert_raise(ArgumentError, fn ->
        named_list = [
          %{"name" => "key1", "value" => "value1"},
          %{"name" => "key1", "value" => "value2"},
          %{"name" => "key3", "some" => "thing"}
        ]

        get_in(named_list, [MUT.access("key1"), "value"])
      end)
    end

    test "raises if argument not a list" do
      assert_raise(ArgumentError, fn ->
        get_in(%{}, [MUT.access("key1"), "value"])
      end)
    end
  end
end
