defmodule K8s.ResourceTest do
  use ExUnit.Case, async: true
  doctest K8s.Resource
  doctest K8s.Resource.FieldAccessors
  doctest K8s.Resource.Utilization

  describe "from_file!/2" do
    test "not found" do
      assert_raise File.Error, fn ->
        K8s.Resource.from_file!("not_found.yaml", [])
      end
    end
  end
end
