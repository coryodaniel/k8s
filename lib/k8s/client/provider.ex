defmodule K8s.Client.Provider do
  @moduledoc "HTTP Request / Response provider behaviour"

  @type success_t :: {:ok, list(map()) | map() | reference() | binary() | list(binary())}
  @type error_t ::
          {:error, K8s.Client.APIError.t() | HTTPoison.Response.t() | HTTPoison.Error.t()}
  @type response_t :: success_t() | error_t()

  @doc "Generate headers for HTTP Requests"
  @callback headers(K8s.Conn.RequestOptions.t()) :: keyword()

  @doc "Deprecated! Use headers/1 instead"
  @callback headers(atom(), K8s.Conn.RequestOptions.t()) :: list({binary, binary})

  @doc "Perform HTTP Requests"
  @callback request(atom, binary, binary, keyword, keyword) :: response_t()

  @doc "Handle HTTP Responses"
  @callback handle_response(
              {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()}
              | {:error, HTTPoison.Error.t()}
            ) :: response_t()
end
