defmodule K8s.Middleware.Request do
  @moduledoc "HTTP Request middleware"

  @typedoc "Middleware Request type"
  @type t :: %__MODULE__{
          conn: K8s.Conn.t(),
          method: atom(),
          uri: URI.t(),
          body: String.t() | map() | list(map()) | nil,
          headers: Keyword.t() | nil,
          opts: Keyword.t() | nil
        }

  defstruct conn: nil, method: nil, uri: nil, body: nil, headers: [], opts: []

  @doc "Request middleware callback"
  @callback call(t()) :: {:ok, t()} | {:error, any()}
end
