defmodule K8s.Conn.Auth do
  @moduledoc """
  Authorization behaviour

  `:skip` is used to signal to `K8s.Conn` to skip a provider that would not authenticate the current connection.
  """

  @callback create(map(), String.t()) :: {:ok, struct} | {:error, any} | :skip
end
