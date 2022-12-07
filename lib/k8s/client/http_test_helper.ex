# credo:disable-for-this-file
defmodule K8s.Client.HTTPTestHelper do
  @moduledoc "HTTP Helpers for test suite."

  def stream_object(object), do: {:data, Jason.encode!(object) <> "\n"}

  def render(data), do: {:ok, data}

  def render(code, reason), do: {:error, K8s.Client.HTTPError.new(message: "#{code} #{reason}")}
end
