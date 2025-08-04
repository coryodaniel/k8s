defmodule K8s.Resource.UtilizationTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest K8s.Resource.Utilization

  alias K8s.Resource.Utilization, as: UT

  describe "cpu parse" do
    test "parses whole values" do
      assert UT.cpu("3") == 3
    end

    test "parses millicpu values" do
      assert UT.cpu("500m") == 0.5
    end

    test "parses nanocpu values" do
      assert UT.cpu("900000n") == 0.0009
    end

    test "parses decimal values" do
      assert UT.cpu("1.5") == 1.5
    end

    test "handles negative values" do
      assert UT.cpu("-500m") == -0.5
    end

    test "handles positive prefixed values" do
      assert UT.cpu("+500m") == 0.5
    end

    test "returns 0 for nil input" do
      assert UT.cpu(nil) == 0
    end
  end
end
