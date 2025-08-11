defmodule K8s.Resource.UtilizationTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest K8s.Resource.Utilization

  alias K8s.Resource.Utilization, as: U

  describe "cpu/1" do
    test "parses whole values" do
      assert U.cpu("3") == 3
    end

    test "parses millicpu values" do
      assert U.cpu("500m") == 0.5
    end

    test "parses nanocpu values" do
      assert U.cpu("900000n") == 0.0009
    end

    test "parses decimal values" do
      assert U.cpu("1.5") == 1.5
    end

    test "handles nil input" do
      assert U.cpu(nil) == 0
    end

    test "handles negative values" do
      assert U.cpu("-500m") == -0.5
    end

    test "handles positive prefixed values" do
      assert U.cpu("+500m") == 0.5
    end

    test "handles invalid input gracefully" do
      assert_raise MatchError, fn -> U.cpu("no match of right hand side value: :error") end
    end
  end
end
