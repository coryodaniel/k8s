defmodule K8s.Client.Provider do
  @moduledoc "HTTP Request / Response provider behaviour"
  alias K8s.Conn.RequestOptions

  @type headers :: [{header_name :: String.t(), header_value :: String.t()}]
  @type stream_chunk_t ::
          {:data | binary}
          | {:status, integer()}
          | {:headers, headers()}
          | {:error, K8s.Client.HTTPError.t()}
          | :done
  @type success_t :: {:ok, list(map()) | map() | reference() | binary() | list(binary())}
  @type stream_success_t :: {:ok, Enumerable.t(stream_chunk_t())}

  @type error_t ::
          {:error, K8s.Client.APIError.t() | K8s.Client.HTTPError.t()}

  @type response_t :: success_t() | error_t()
  @type stream_response_t :: stream_success_t() | error_t()

  @doc "Perform HTTP requests"
  @callback request(
              method :: atom(),
              uri :: URI.t(),
              body :: binary,
              headers :: list(),
              http_opts :: keyword()
            ) :: response_t()

  @doc "Perform HTTP requests and stream response"
  @callback stream(
              method :: atom(),
              uri :: URI.t(),
              body :: binary,
              headers :: list(),
              http_opts :: keyword()
            ) :: stream_response_t()

  @doc "Perform Websocket requests and stream response"
  @callback websocket_stream(
              uri :: URI.t(),
              headers :: list(),
              http_opts :: keyword()
            ) :: stream_response_t()

  @doc """
  Generates HTTP headers from `K8s.Conn.RequestOptions`

  * Adds `{:Accept, "application/json"}` to all requests if the header is not set.

  ## Examples
    Sets `Content-Type` to `application/json`
      iex> opts = %K8s.Conn.RequestOptions{headers: [Authorization: "Basic AF"]}
      ...> K8s.Client.HTTPProvider.headers(opts)
      [Accept: "application/json", Authorization: "Basic AF"]
  """
  @spec headers(K8s.Conn.RequestOptions.t()) :: keyword()
  def headers(%RequestOptions{} = opts),
    do: Keyword.put_new(opts.headers, :Accept, "application/json")
end
