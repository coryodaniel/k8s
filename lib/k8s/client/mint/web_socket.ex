defmodule K8s.Client.Mint.WebSocket do
  @moduledoc """
  Websocket implementation of Mint based `K8s.Client.Provider`
  """

  alias K8s.Client.Mint.ConnectionRegistry
  alias K8s.Client.Mint.HTTPAdapter
  alias K8s.Client.Provider

  @data_types [:data, :stdout, :stderr, :error]

  @spec request(uri :: URI.t(), headers :: list(), http_opts :: keyword()) ::
          Provider.websocket_response_t()
  def request(uri, headers, http_opts) do
    with {:ok, stream} <- stream(uri, headers, http_opts) do
      response =
        stream
        |> Stream.reject(&(&1 == {:done, true}))
        |> Enum.reduce(%{}, fn
          {type, data}, response when type in @data_types ->
            Map.update(response, type, [data], &[data | &1])

          {type, value}, response ->
            Map.put(response, type, value)
        end)

      response =
        @data_types
        |> Enum.reduce(response, fn type, response ->
          Map.update(response, type, nil, &(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
        end)
        |> Map.reject(&(&1 |> elem(1) |> is_nil()))

      {:ok, response}
    end
  end

  @spec stream(uri :: URI.t(), headers :: list(), http_opts :: keyword()) ::
          Provider.stream_response_t()
  def stream(uri, headers, http_opts) do
    with {:ok, _} <- stream_to(uri, headers, http_opts, self()) do
      stream =
        Stream.unfold(:open, fn
          :close ->
            nil

          :open ->
            receive do
              {:close, data} -> {{:close, data}, :close}
              other -> {other, :open}
            end
        end)

      {:ok, stream}
    end
  end

  @spec stream_to(uri :: URI.t(), headers :: list(), http_opts :: keyword(), stream_to :: pid()) ::
          Provider.stream_to_response_t()
  def stream_to(uri, headers, http_opts, stream_to) do
    {opts, path, headers} = prepare_args(uri, headers, http_opts)

    with {:ok, %{adapter: adapter_pid, pool: pool}} <-
           ConnectionRegistry.checkout({uri, opts}) do
      HTTPAdapter.websocket_stream_to(adapter_pid, path, headers, pool, stream_to)
    end
  end

  @spec prepare_args(uri :: URI.t(), headers :: list(), http_opts :: keyword()) ::
          {keyword(), binary(), list()}
  defp prepare_args(uri, headers, http_opts) do
    opts = [transport_opts: Keyword.fetch!(http_opts, :ssl), protocols: [:http1]]
    path = K8s.Client.Mint.HTTP.uri_to_path(uri)
    headers = Enum.map(headers, fn {header, value} -> {"#{header}", "#{value}"} end)
    {opts, path, headers}
  end
end
