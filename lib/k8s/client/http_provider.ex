defmodule K8s.Client.HTTPProvider do
  @moduledoc """
  HTTPoison and Jason based `K8s.Behaviours.HTTPProvider`
  """
  @behaviour K8s.Behaviours.HTTPProvider
  alias K8s.Conf.RequestOptions

  @impl true
  def request(method, url, body, headers, opts) do
    handle_response(HTTPoison.request(method, url, body, headers, opts))
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

  Handles 4xx responses:

      iex> K8s.Client.HTTPProvider.handle_response({:ok, %HTTPoison.Response{status_code: 410, body: "Gone"}})
      {:error, "HTTP Error: 410; Gone"}

  Handles HTTPoison error responses:

      iex> K8s.Client.HTTPProvider.handle_response({:error, %HTTPoison.Error{reason: "Foo"}})
      {:error, "HTTP Client Error: Foo"}

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

      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 400..599 ->
        {:error, "HTTP Error: #{code}; #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP Client Error: #{reason}"}
    end
  end

  @doc """
  Appends `Accept` and `Content-Type` headers to `K8s.Conf.RequestOptions` headers.

  ## Example

      iex> ro = %K8s.Conf.RequestOptions{headers: [{"Authorization", "Basic AF"}]}
      ...> K8s.Client.HTTPProvider.headers(ro)
      [{"Authorization", "Basic AF"},{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  """
  @impl true
  def headers(ro = %RequestOptions{}) do
    ro.headers ++ [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
  end

  @spec decode(binary()) :: list | map | nil
  defp decode(body) do
    case Jason.decode(body) do
      {:ok, data} -> data
      {:error, _} -> nil
    end
  end
end
