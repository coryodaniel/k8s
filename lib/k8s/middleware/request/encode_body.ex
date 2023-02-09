defmodule K8s.Middleware.Request.EncodeBody do
  @moduledoc """
  Naive JSON body encoder.

  Encodes JSON payloads when given an modifiying HTTP verb, otherwise returns an empty string.
  """
  @behaviour K8s.Middleware.Request
  alias K8s.Middleware.Request

  @impl true
  def call(%Request{method: method, body: body} = req) do
    case encode(body, method) do
      {:ok, encoded_body} ->
        req = %Request{req | body: encoded_body}
        {:ok, req}

      error ->
        error
    end
  end

  @spec encode(any(), atom()) :: {:ok, binary} | {:error, any}
  defp encode(body, http_method) when http_method in [:put, :patch, :post], do: Jason.encode(body)
  defp encode(_, _), do: {:ok, nil}
end
