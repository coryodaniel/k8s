defmodule K8s.Test.HTTPHelper do
  @moduledoc "HTTP Helpers for test suite."

  @spec render(any, integer) :: {:ok, HTTPoison.Response.t()}
  def render(data, code \\ 200) do
    body = Jason.encode!(data)
    {:ok, %HTTPoison.Response{status_code: code, body: body}}
  end
end
