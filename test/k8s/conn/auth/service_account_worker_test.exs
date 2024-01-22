defmodule K8s.Conn.Auth.ServiceAccountWorkerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias K8s.Conn.Auth.ServiceAccountWorker

  describe "refresh cycle" do
    @tag :integration
    test "sees tokens change" do
      id = Enum.random(0..99_999)
      path = System.tmp_dir() <> "/k8s-elixir-test-token-" <> Integer.to_string(id)

      first_content = "gigawatts"
      second_contents = "pirate radio"

      File.write!(path, first_content)

      {:ok, pid} = ServiceAccountWorker.start_link(path: path, refresh_interval: 50)
      assert {:ok, "gigawatts"} == ServiceAccountWorker.get_token(pid)

      res = Task.async(fn -> File.write!(path, second_contents) end)

      # We still see the chached version and aren't refreshing like crazy.
      assert {:ok, "gigawatts"} == ServiceAccountWorker.get_token(pid)

      Task.await(res, 500)

      assert 0..4
             |> Enum.map(fn _ ->
               Process.sleep(50)
               {:ok, token} = ServiceAccountWorker.get_token(pid)
               token
             end)
             |> Enum.map(fn t -> t == second_contents end)
             |> Enum.any?(fn x -> x end)

      File.rm!(path)
    end

    test "works with simple token file" do
      {:ok, pid} =
        ServiceAccountWorker.start_link(path: "test/support/tls/token", refresh_interval: 100)

      assert {:ok, "imatoken"} == ServiceAccountWorker.get_token(pid)
    end
  end
end
