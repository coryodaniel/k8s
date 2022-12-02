# credo:disable-for-this-file
defmodule K8s.Test.HTTPHelper do
  @moduledoc "HTTP Helpers for test suite."
  def stream_object(object), do: {:data, Jason.encode!(object) <> "\n"}

  def send_object(pid, object), do: send_chunk(pid, Jason.encode!(object) <> "\n")

  def send_chunk(pid, chunk),
    do: send(pid, %HTTPoison.AsyncChunk{chunk: chunk})
end
