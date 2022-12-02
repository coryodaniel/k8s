defmodule K8s.Client.Provider do
  @moduledoc "HTTP Request / Response provider behaviour"

  @type success_t :: {:ok, list(map()) | map() | reference() | binary() | list(binary())}

  @type error_t ::
          {:error, K8s.Client.APIError.t() | K8s.Client.HTTPError.t()}

  @type response_t :: success_t() | error_t()

  @doc "Generate headers for HTTP Requests"
  @callback headers(K8s.Conn.RequestOptions.t()) :: keyword()

  @doc "Perform HTTP Requests"
  @callback request(atom, binary, binary, keyword, keyword) :: response_t()

  @doc "Perform HTTP Requests and stream response"
  @callback stream(atom, binary, binary, keyword, keyword) :: Stream.t()
end
