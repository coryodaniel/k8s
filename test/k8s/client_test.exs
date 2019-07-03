defmodule K8s.ClientTest do
  use ExUnit.Case, async: true
  doctest K8s.Client

  doctest K8s.Client.HTTPProvider
end
