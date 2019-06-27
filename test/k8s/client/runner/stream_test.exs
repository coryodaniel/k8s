defmodule K8s.Client.Runner.StreamTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true
  doctest K8s.Client.Runner.Stream
  doctest K8s.Client.Runner.Stream.ListRequest
  alias K8s.Client.Runner.Stream

  describe "run/3" do
    test "when the initial request has no results" do
      operation = K8s.Client.list("v1", "Service", namespace: "stream-empty-test")
      cluster = :test
      assert {:ok, stream} = Stream.run(operation, cluster)

      services = Enum.into(stream, [])
      assert services == []
    end

    test "puts HTTPProvider error tuples into the stream when HTTP errors are encountered" do
      operation = K8s.Client.list("v1", "Service", namespace: "stream-failure-test")
      cluster = :test
      assert {:ok, stream} = Stream.run(operation, cluster)

      services = Enum.into(stream, [])

      assert services == [
               %{
                 "apiVersion" => "v1",
                 "kind" => "Service",
                 "metadata" => %{"name" => "foo", "namespace" => "stream-failure-test"}
               },
               {:error, :not_found}
             ]
    end

    test "returns an enumerable stream of k8s resources" do
      operation = K8s.Client.list("v1", "Service", namespace: "stream-runner-test")
      cluster = :test
      assert {:ok, stream} = Stream.run(operation, cluster)

      services = Enum.into(stream, [])

      assert services == [
               %{
                 "apiVersion" => "v1",
                 "kind" => "Service",
                 "metadata" => %{"name" => "foo", "namespace" => "stream-runner-test"}
               },
               %{
                 "apiVersion" => "v1",
                 "kind" => "Service",
                 "metadata" => %{"name" => "bar", "namespace" => "stream-runner-test"}
               },
               %{
                 "apiVersion" => "v1",
                 "kind" => "Service",
                 "metadata" => %{"name" => "qux", "namespace" => "stream-runner-test"}
               }
             ]
    end
  end
end
