defmodule K8s.Client.Provider do
  @moduledoc "HTTP Request / Response provider behaviour"
  alias K8s.Conn.RequestOptions

  @type success_t :: {:ok, list(map()) | map() | reference() | binary() | list(binary())}

  @type error_t ::
          {:error, K8s.Client.APIError.t() | K8s.Client.HTTPError.t()}

  @type response_t :: success_t() | error_t()

  @doc "Perform HTTP Requests"
  @callback request(atom, binary, binary, keyword, keyword) :: response_t()

  @doc "Perform HTTP Requests and stream response"
  @callback stream(atom, binary, binary, keyword, keyword) :: Stream.t()

  @doc """
  Generates HTTP headers from `K8s.Conn.RequestOptions`

  * Adds `{:Accept, "application/json"}` to all requests if the header is not set.

  ## Examples
    Sets `Content-Type` to `application/json`
      iex> opts = %K8s.Conn.RequestOptions{headers: [Authorization: "Basic AF"]}
      ...> K8s.Client.HTTPProvider.headers(opts)
      [Accept: "application/json", Authorization: "Basic AF"]
  """
  def headers(%RequestOptions{} = opts),
    do: Keyword.put_new(opts.headers, :Accept, "application/json")
end
