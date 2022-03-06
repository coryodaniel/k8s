defmodule K8s.ResourceTest do
  use ExUnit.Case, async: true
  doctest K8s.Resource
  doctest K8s.Resource.FieldAccessors
  doctest K8s.Resource.Utilization

  @test_file "k8s_tmp_file"
  @test_directory "k8s_tmp_dir"

  setup do
    on_exit(fn ->
      File.rm(@test_file)
      File.rmdir(@test_directory)
    end)
  end

  describe "from_file!/2" do
    test "not found" do
      assert_raise File.Error, fn ->
        K8s.Resource.from_file!("not_found.yaml", [])
      end
    end

    test "is directory" do
      assert_raise File.Error, fn ->
        File.mkdir(@test_directory)
        K8s.Resource.from_file!("k8s_tmpdir", [])
      end
    end

    test "has no access to file" do
      assert_raise File.Error, fn ->
        File.touch(@test_file)
        File.chmod(@test_file, 0o000)

        K8s.Resource.from_file!(@test_file, [])
      end
    end
  end
end
