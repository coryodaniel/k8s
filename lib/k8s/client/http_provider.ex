defmodule K8s.Client.HTTPProvider do
  @moduledoc """
  HTTPoison and Jason based `K8s.Client.Provider`
  """
  @behaviour K8s.Client.Provider
  alias K8s.Conn.RequestOptions
  require Logger

  @impl true
  def request(method, url, body, headers, http_opts) do
    :telemetry.span([:http, :request], %{method: method, url: url}, fn ->
      response = HTTPoison.request(method, url, body, headers, http_opts)

      case handle_response(response) do
        {:ok, result} ->
          {{:ok, result}, %{}}

        {:error, error} ->
          {{:error, error}, %{error: error}}
      end
    end)
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
      {:error,  %HTTPoison.Response{body: nil, headers: [], request: nil, request_url: nil, status_code: 401}}

  Handles not found responses:

      iex> body = ~s({"kind":"Status","apiVersion":"v1","metadata":{},"status":"Failure","message":"namespaces not found","reason":"NotFound","details":{"name":"i-dont-exist","kind":"namespaces"},"code":404})
      ...> headers = [{"Content-Type", "application/json"}]
      ...> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 404, body: body, headers: headers}})
      {:error, %K8s.Client.APIError{message: "namespaces not found", reason: "NotFound"}}

  Handles admission hook responses:
      iex> body = ~s({"apiVersion":"v1","code":400,"kind":"Status","message":"admission webhook","metadata" :{}, "status":"Failure"})
      ...> headers = [{"Content-Type", "application/json"}]
      ...> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 404, body: body, headers: headers}})
      {:error, %K8s.Client.APIError{message: "admission webhook", reason: "Failure"}}

  Passes through HTTPoison 4xx responses:

      iex> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 410, body: "Gone"}})
      {:error,  %HTTPoison.Response{body: "Gone", headers: [], request: nil, request_url: nil, status_code: 410}}

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
        content_type = get_content_type(headers)
        {:ok, decode(body, content_type)}

      %HTTPoison.Response{status_code: code} = err
      when code in 400..599 ->
        handle_error(err)
    end
  end

  @spec handle_error(HTTPoison.Response.t()) ::
          {:error, K8s.Client.APIError.t() | HTTPoison.Response.t()}
  defp handle_error(%HTTPoison.Response{status_code: _, body: body, headers: headers} = resp) do
    case get_content_type(headers) do
      "application/json" = content_type ->
        body |> decode(content_type) |> handle_kubernetes_error()

      _http_error ->
        {:error, resp}
    end
  end

  # Kubernetes specific errors are typically wrapped in a JSON body
  # see: https://github.com/kubernetes/apimachinery/blob/master/pkg/api/errors/errors.go
  # so one must differentiate between e.g ordinary 404s and kubernetes 404
  @spec handle_kubernetes_error(map) :: {:error, K8s.Client.APIError.t()}
  defp handle_kubernetes_error(%{"reason" => reason, "message" => message}) do
    err = %K8s.Client.APIError{message: message, reason: reason}
    {:error, err}
  end

  defp handle_kubernetes_error(%{"status" => "Failure", "message" => message}) do
    err = %K8s.Client.APIError{message: message, reason: "Failure"}
    {:error, err}
  end

  @doc """
  Generates HTTP headers from `K8s.Conn.RequestOptions`

  * Adds `{:Accept, "application/json"}` to all requests if the header is not set.

  ## Examples
    Sets `Content-Type` to `application/json`
      iex> opts = %K8s.Conn.RequestOptions{headers: [Authorization: "Basic AF"]}
      ...> K8s.Client.HTTPProvider.headers(opts)
      [Accept: "application/json", Authorization: "Basic AF"]
  """
  @impl true
  def headers(%RequestOptions{} = opts),
    do: Keyword.put_new(opts.headers, :Accept, "application/json")

  @doc """
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
  @deprecated "Use headers/1 instead"
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

  @spec decode(binary, binary) :: map | list | nil
  defp decode(body, "text/plain"), do: body

  defp decode(body, _default_json_decoder) do
    case Jason.decode(body) do
      {:ok, data} -> data
      {:error, _} -> nil
    end
  end

  @spec get_content_type(keyword()) :: binary | nil
  defp get_content_type(headers) do
    case List.keyfind(headers, "Content-Type", 0) do
      {_key, content_type} -> content_type
      _ -> nil
    end
  end
end
