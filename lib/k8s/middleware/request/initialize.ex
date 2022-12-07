defmodule K8s.Middleware.Request.Initialize do
  @moduledoc """
  Initializes a request with connection details (header and HTTPoison opts) from `K8s.Conn.RequestOptions`
  """
  @behaviour K8s.Middleware.Request
  alias K8s.Middleware.Request

  @impl true
  def call(%Request{conn: conn, headers: headers, opts: opts} = req) do
    with {:ok, request_options} <- K8s.Conn.RequestOptions.generate(conn) do
      request_option_headers = K8s.Client.Provider.headers(request_options)
      updated_headers = Keyword.merge(headers, request_option_headers)
      updated_opts = Keyword.merge([ssl: request_options.ssl_options], opts)
      updated_request = %Request{req | headers: updated_headers, opts: updated_opts}
      {:ok, updated_request}
    end
  end
end
