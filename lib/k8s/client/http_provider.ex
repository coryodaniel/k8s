defmodule K8s.Client.HTTPProvider do
  @moduledoc """
  HTTPoison and Jason based `K8s.Client.Behaviour`
  """
  @behaviour K8s.Client.Behaviour
  alias K8s.Conf.RequestOptions

  @impl true
  def request(method, url, body, headers, opts) do
    content_type = content_type_header(method)
    headers = [content_type | headers]
    {duration, response} = :timer.tc(HTTPoison, :request, [method, url, body, headers, opts])
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

  @spec content_type_header(atom()) :: {binary(), binary()}
  defp content_type_header(:patch) do
    {"Content-Type", "application/merge-patch+json"}
  end

  defp content_type_header(_http_method) do
    {"Content-Type", "application/json"}
  end

  @doc """
  Handle HTTPoison responses and errors

  ## Examples

  Parses successful JSON responses:

      iex> body = ~s({"foo": "bar"})
      ...> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 200, body: body}})
      {:ok, %{"foo" => "bar"}}

  Handles unauthorized responses:

      iex> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 401}})
      {:error, :unauthorized}

  Handles not found responses:

      iex> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 404}})
      {:error, :not_found}

  Passes through HTTPoison 4xx responses:

      iex> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 410, body: "Gone"}})
      {:error, %HTTPoison.Response{status_code: 410, body: "Gone"}}

  Passes through HTTPoison error responses:

      iex> K8s.Client.HTTPProvider.handle_response({:error, %HTTPoison.Error{reason: "Foo"}})
      {:error, %HTTPoison.Error{reason: "Foo"}}

  """
  @impl true
  def handle_response(resp) do
    case resp do
      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 200..299 ->
        {:ok, decode(body)}

      {:ok, %HTTPoison.AsyncResponse{id: ref}} ->
        {:ok, ref}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, :unauthorized}

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{status_code: code} = resp} when code in 400..599 ->
        {:error, resp}

      {:error, %HTTPoison.Error{} = err} ->
        {:error, err}
    end
  end

  @doc """
  Generates HTTP headers from `K8s.Conf.RequestOptions`
  ## Example

      iex> opts = %K8s.Conf.RequestOptions{headers: [{"Authorization", "Basic AF"}]}
      ...> K8s.Client.HTTPProvider.headers(opts)
      [{"Accept", "application/json"}, {"Authorization", "Basic AF"}]
  """
  @impl true
  def headers(%RequestOptions{} = opts) do
    [{"Accept", "application/json"} | opts.headers]
  end

  @spec decode(binary()) :: list | map | nil
  defp decode(body) do
    case Jason.decode(body) do
      {:ok, data} -> data
      {:error, _} -> nil
    end
  end
end
