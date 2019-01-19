defmodule K8s.SwaggerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest K8s.Swagger
  alias K8s.Swagger

  describe "gen_action_name/1" do
    test "defaults to the metadata's action" do
      metadata = %{"action" => "delete"}

      assert "delete" == Swagger.gen_action_name(metadata)
    end

    test "returns an 'all namespaces' action when all_namespaces is true" do
      metadata = %{"action" => "list", "all_namespaces" => true}

      assert "list_all_namespaces" == Swagger.gen_action_name(metadata)
    end
  end

  describe "build/1" do
    test "parses a swagger spec into operation metadata" do
      metadata = Swagger.build("./priv/custom/simple.json")
      operation = metadata["createAppsV1NamespacedDeployment"]

      assert operation["action"] == "post"
      assert operation["all_namespaces"] == false
      assert operation["api_version"] == "apps/v1"
      assert operation["desc"] == "create a Deployment"
      assert operation["id"] == "createAppsV1NamespacedDeployment"
      assert operation["kind"] == "Deployment"
      assert operation["method"] == "post"

      assert operation["params"] == [
               %{
                 "in" => "body",
                 "name" => "body",
                 "required" => true,
                 "schema" => %{"$ref" => "#/definitions/io.k8s.api.apps.v1.Deployment"}
               },
               %{
                 "description" =>
                   "When present, indicates that modifications should not be persisted. An invalid or unrecognized dryRun directive will result in an error response and no further processing of the request. Valid values are: - All: all dry run stages will be processed",
                 "in" => "query",
                 "name" => "dryRun",
                 "type" => "string",
                 "uniqueItems" => true
               }
             ]

      assert operation["path"] == "/apis/apps/v1/namespaces/{namespace}/deployments"
      assert operation["path_params"] == [:namespace]
    end
  end
end
