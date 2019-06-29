defmodule K8s.Behaviours.DiscoveryProvider do
  @moduledoc """
  Kubernetes API Discovery behavior
  """

  @callback resource_definitions_by_group(atom, keyword) ::
              {:ok, list(map)} | {:error, HTTPoison.Response.t()}
end
