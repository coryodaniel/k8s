defmodule K8s.Client.Mint.RequestWindow do
  @moduledoc """
  Just some hacks to make the Dialyzer happy.

  We need to get the usable window size for
  requests while they are in flight and before
  starting. However some Mint's HTTP2 connection
  is opaque and these details are not exposed
  easily.
  """

  @default_max_frame_size 16_384
  @default_window_size 16_384

  @spec window_size(Mint.HTTP.t(), :new | Mint.Types.request_ref()) :: non_neg_integer
  def window_size(conn, new_or_request)

  def window_size(conn, :new) do
    # When a new request is starting we can send the minimum of:
    # - The connections's requests window size. That's the total bytes that can be outstanding to the server
    # - The maximum frame size the server settings have minus some room for the frame overhead
    [
      connection_window_size(conn),
      max_frame_size(conn) - 4096
    ]
    |> Enum.min()
    |> max(0)
  end

  def window_size(conn, request_ref) do
    [
      connection_window_size(conn),
      request_request_window_size(conn, request_ref)
    ]
    |> Enum.min()
    |> max(0)
  end

  @opaque http2 :: %Mint.HTTP2{}
  # Haha trick dialyzer into really accepting that it can't see into http2.
  @spec type_cast_http2(http2()) :: http2() | Mint.HTTP2.t()
  defp type_cast_http2(%Mint.HTTP2{} = conn) do
    # This is necessary becuase conn types in Mint are opaque.
    #
    # Using opaque makes me everyone cry.
    # It's not a fun experience.
    # Who signed us up for this?
    #
    # See [elixir-mint/mint#380](https://github.com/elixir-mint/mint/issues/380) for
    # the discussion on it.
    conn
  end

  @spec connection_window_size(any()) :: non_neg_integer()
  def connection_window_size(%Mint.HTTP2{} = conn) do
    conn
    |> type_cast_http2()
    |> Mint.HTTP2.get_window_size(:connection)
  end

  def connection_window_size(_) do
    @default_window_size
  end

  @spec request_request_window_size(any(), Mint.Types.request_ref()) :: non_neg_integer()
  def request_request_window_size(%Mint.HTTP2{} = conn, request_ref) do
    conn
    |> type_cast_http2()
    |> Mint.HTTP2.get_window_size({:request, request_ref})
  end

  def request_request_window_size(_, _) do
    @default_window_size
  end

  #
  # Below are functions to get at the internals of Mint's http2 connection
  # These fields don't feel like public api space. As such there are
  # default fall backs that are conservative.
  #

  @spec max_frame_size(any()) :: non_neg_integer()
  def max_frame_size(%{server_settings: %{max_frame_size: max_frame_size}} = _conn) do
    max_frame_size
  end

  def max_frame_size(_conn) do
    @default_max_frame_size
  end
end
