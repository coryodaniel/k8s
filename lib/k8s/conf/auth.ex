defmodule K8s.Conf.Auth do
  @moduledoc """
  Authorization behaviour
  """

  @callback create(map(), String.t()) :: struct | nil
end
