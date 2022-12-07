defmodule K8s.Client.StreamTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias K8s.Client.HTTPStream, as: MUT

  describe "transform_to_lines/1" do
    test "Transformes data chunks to lines" do
      actual =
        [
          {:data, "a\na"},
          {:data, "a\na\na"},
          {:data, "a"},
          {:data, "a"},
          :done
        ]
        |> MUT.transform_to_lines()
        |> Enum.to_list()

      expected = [
        {:line, "a"},
        {:line, "aa"},
        {:line, "a"},
        {:line, "aaa"},
        :done
      ]

      assert expected == actual
    end

    test "Forwards other responses, too" do
      actual =
        [
          {:status, 200},
          {:headers, [{"content-type", "application/json"}]},
          {:data, "a"},
          :done
        ]
        |> MUT.transform_to_lines()
        |> Enum.to_list()

      expected = [
        {:status, 200},
        {:headers, [{"content-type", "application/json"}]},
        {:line, "a"},
        :done
      ]

      assert expected == actual
    end
  end

  describe "decode_json_objects/1" do
    test "decodes valid json lines" do
      actual =
        [
          {:line,
           ~s|{"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "test", "namespace": "default"}}|},
          {:line,
           ~s|{"apiVersion": "v1", "kind": "Secret", "metadata": {"name": "test", "namespace": "default"}}|},
          :done
        ]
        |> MUT.decode_json_objects()
        |> Enum.to_list()

      expected = [
        {:object,
         %{
           "apiVersion" => "v1",
           "kind" => "ConfigMap",
           "metadata" => %{"name" => "test", "namespace" => "default"}
         }},
        {:object,
         %{
           "apiVersion" => "v1",
           "kind" => "Secret",
           "metadata" => %{"name" => "test", "namespace" => "default"}
         }},
        :done
      ]

      assert expected == actual
    end

    test "decodes valid json chunks" do
      actual =
        [
          {:data, ~s|{"apiVersion": "v1|},
          {:data, ~s|", "kind": "ConfigMap", "metada|},
          {:data, ~s|ta": {"name": "test", "namespace": "default"}}\n|},
          :done
        ]
        |> MUT.decode_json_objects()
        |> Enum.to_list()

      expected = [
        {:object,
         %{
           "apiVersion" => "v1",
           "kind" => "ConfigMap",
           "metadata" => %{"name" => "test", "namespace" => "default"}
         }},
        :done
      ]

      assert expected == actual
    end

    test "logs if invalid json" do
      log =
        capture_log(fn ->
          [
            {:data, ~s|{"apiVersion": "v1|},
            {:data, ~s|", "kind": "ConfigMap", "metada|},
            {:data, ~s|ta": {"name": "test", "namespace": "default"}\n|},
            :done
          ]
          |> MUT.decode_json_objects()
          |> Enum.to_list()
        end)

      assert log =~ "Could not decode JSON"
    end
  end
end
