defmodule K8s.ResourceTest do
  use ExUnit.Case, async: true
  doctest K8s.Resource
  doctest K8s.Resource.FieldAccessors
  doctest K8s.Resource.Utilization
end
