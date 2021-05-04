defmodule K8s.Client.HTTPProvider do
  @moduledoc """
  HTTPoison and Jason based `K8s.Client.Provider`
  """
  @behaviour K8s.Client.Provider
  alias K8s.Conn.RequestOptions
  require Logger

  @impl true
  def request(method, url, body, headers, http_opts) do
    {duration, response} = :timer.tc(HTTPoison, :request, [method, url, body, headers, http_opts])
    measurements = %{duration: duration}
    metadata = %{method: method}

    case handle_response(response) do
      {:ok, any} ->
        K8s.Sys.Event.http_request_succeeded(measurements, metadata)
        {:ok, any}

      {:error, any} ->
        K8s.Sys.Event.http_request_failed(measurements, metadata)
        {:error, any}
    end
  end

  @doc """
  Handle HTTPoison responses and errors

  ## Examples

  Parses successful JSON responses:

      iex> body = ~s({"foo": "bar"})
      ...> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 200, body: body}})
      {:ok, %{"foo" => "bar"}}

  Parses successful JSON responses:

      iex> body = "line 1\\nline 2\\nline 3\\n"
      ...> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 200, body: body, headers: [{"Content-Type", "text/plain"}]}})
      {:ok, "line 1\\nline 2\\nline 3\\n"}

  Handles unauthorized responses:

      iex> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 401}})
      {:error, :unauthorized}

  Handles not found responses:

      iex> body = ~s({"kind":"Status","apiVersion":"v1","metadata":{},"status":"Failure","message":"namespaces not found","reason":"NotFound","details":{"name":"i-dont-exist","kind":"namespaces"},"code":404})
      ...> headers = [{"Content-Type", "application/json"}]
      ...> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 404, body: body, headers: headers}})
      {:error, :not_found}

  Passes through HTTPoison 4xx responses:

      iex> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 410, body: "Gone"}})
      {:error, %HTTPoison.Response{status_code: 410, body: "Gone"}}

  Passes through HTTPoison error responses:

      iex> K8s.Client.HTTPProvider.handle_response({:error, %HTTPoison.Error{reason: "Foo"}})
      {:error, %HTTPoison.Error{reason: "Foo"}}

  """
  @impl true
  def handle_response({:error, %HTTPoison.Error{} = err}), do: {:error, err}
  def handle_response({:ok, %HTTPoison.AsyncResponse{id: ref}}), do: {:ok, ref}

  def handle_response({:ok, resp}) do
    case resp do
      %HTTPoison.Response{status_code: code, body: body, headers: headers}
      when code in 200..299 ->
        content_type = List.keyfind(headers, "Content-Type", 0)
        {:ok, decode(body, content_type)}

      %HTTPoison.Response{status_code: 404, body: body, headers: headers} ->
        msg = format_log_message(body, headers)
        Logger.error(msg)

        {:error, :not_found}

      %HTTPoison.Response{status_code: 401} ->
        {:error, :unauthorized}

      %HTTPoison.Response{status_code: code} when code in 400..599 ->
        {:error, resp}
    end
  end

  @doc """
  Generates HTTP headers from `K8s.Conn.RequestOptions`

  * Adds `{"Accept", "application/json"}` to all requests.
  * Adds `Content-Type` base on HTTP method.

  ## Examples
    Sets `Content-Type` to `application/merge-patch+json` for PATCH operations
      iex> opts = %K8s.Conn.RequestOptions{headers: [{"Authorization", "Basic AF"}]}
      ...> K8s.Client.HTTPProvider.headers(:patch, opts)
      [{"Accept", "application/json"}, {"Content-Type", "application/merge-patch+json"}, {"Authorization", "Basic AF"}]

    Sets `Content-Type` to `application/json` for all other operations
      iex> opts = %K8s.Conn.RequestOptions{headers: [{"Authorization", "Basic AF"}]}
      ...> K8s.Client.HTTPProvider.headers(:get, opts)
      [{"Accept", "application/json"}, {"Content-Type", "application/json"}, {"Authorization", "Basic AF"}]
  """
  @impl true
  def headers(method, %RequestOptions{} = opts) do
    defaults = [{"Accept", "application/json"}, content_type_header(method)]
    defaults ++ opts.headers
  end

  @spec content_type_header(atom()) :: {binary(), binary()}
  defp content_type_header(:patch) do
    {"Content-Type", "application/merge-patch+json"}
  end

  defp content_type_header(_http_method) do
    {"Content-Type", "application/json"}
  end

  @spec decode(binary(), {binary(), binary()} | nil) :: list | map | nil
  defp decode(body, {_, "text/plain"}), do: body

  defp decode(body, _default_json_decoder) do
    case Jason.decode(body) do
      {:ok, data} -> data
      {:error, _} -> nil
    end
  end

  @spec format_log_message(String.t(), [tuple]) :: any
  def format_log_message(body, headers) do
    content_type = List.keyfind(headers, "Content-Type", 0)

    case decode(body, content_type) do
      %{"message" => msg} -> msg
      msg -> msg
    end
  end
end
