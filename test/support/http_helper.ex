defmodule K8s.Test.HTTPHelper do
  @moduledoc "HTTP Helpers for test suite."

  @spec render(any, integer) :: {:ok, HTTPoison.Response.t()}
  def render(data), do: render(data, 200)
  def render(data, code), do: render(data, code, [])

  def render(data, code, headers) do
    body = Jason.encode!(data)
    {:ok, %HTTPoison.Response{status_code: code, body: body, headers: headers}}
  end
end
