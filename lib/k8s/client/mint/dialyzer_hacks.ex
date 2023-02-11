defmodule K8s.Client.Mint.DialyzerHacks do
  @moduledoc """
  Just some hacks to make the Dialyzer happy.
  """

  @spec type_cast_http2(Mint.HTTP.t()) :: Mint.HTTP2.t()
  defp type_cast_http2(conn), do: conn

  @doc """
  Dialyzer safe version of `Mint.HTTP2.get_window_size/2`. Uses
  `type_cast_http2/1` which tells Dialyzer that the conn is actually a HTTP2
  conn. This is necessary becuase conn types in Mint are opaque.

  See [elixir-mint/mint#380](https://github.com/elixir-mint/mint/issues/380) for
  the discussion on it.
  """
  @spec get_window_size(Mint.HTTP.t(), :connection | {:request, Mint.Types.request_ref()}) ::
          non_neg_integer
  def get_window_size(conn, connection_or_request) do
    conn
    |> type_cast_http2()
    |> Mint.HTTP2.get_window_size(connection_or_request)
  end
end
