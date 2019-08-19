defmodule K8s.Conn.Auth do
  @moduledoc """
  Authorization behaviour
  """

  @callback create(map(), String.t()) :: struct | nil
end
