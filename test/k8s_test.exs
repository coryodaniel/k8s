defmodule K8sTest do
  use ExUnit.Case, async: true
  doctest K8s
  doctest K8s.Client
  doctest K8s.Operation
  doctest K8s.Version
  doctest K8s.Client.HTTPProvider
end
