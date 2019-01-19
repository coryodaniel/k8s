defmodule Mix.Tasks.K8s.SwaggerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Mix.Tasks.K8s.Swagger
  import ExUnit.CaptureIO

  describe "run/1" do
    @tag external: true
    test "downloads a swagger spec" do
      output =
        capture_io(fn ->
          Swagger.run(["-v", "1.13", "--out", "-"])
        end)

      assert output =~ ~s("paths")
      assert output =~ "io.k8s.api"
    end
  end
end
