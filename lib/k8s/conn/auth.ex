defmodule K8s.Conn.Auth do
  @moduledoc """
  Authorization behaviour
  """

  @doc """
  Creates a struct holding the information to authenticate against the
  API server.

  ### Arguments

  * `auth_map` - A map representing the `.users[].user` part from a kubeconfig.
  * `base_path` - The path to the folder holding the kubeconfig file.

  ### Result

  The struct returned by this function MUST implement the
  `K8s.Conn.RequestOptions` protocol.
  Return `:skip` to signal to `K8s.Conn` to skip a provider that would not
  authenticate the current connection.

  ### Examples

  See the various modules implementing this behaviour for examples.
  """
  @callback create(auth_map :: map(), base_path :: String.t()) ::
              {:ok, struct} | {:error, any} | :skip
end
