defmodule K8s.Client.Mint.DialyzerHacks do
  @moduledoc """
  Just some hacks to make the Dialyzer happy
  """

  @doc """
  This function tells Dialyzer that the conn is actually a HTTP2 conn.
  """
  @spec make_http2(Mint.HTTP.t()) :: Mint.HTTP2.t()
  def make_http2(conn), do: conn
end
