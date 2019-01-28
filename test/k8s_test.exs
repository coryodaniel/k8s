defmodule K8sTest do
  use ExUnit.Case
  doctest K8s
  doctest K8s.Client
  doctest K8s.Operation
  doctest K8s.Path
  doctest K8s.Resource
  doctest K8s.Version
end
