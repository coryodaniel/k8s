defmodule K8s.Sys.Telemetry do
  @moduledoc false

  @spans [
    [:http, :request]
  ]

  @spec spans() :: list()
  def spans, do: @spans

  @spec events() :: list()
  def events do
    @spans
    |> Enum.flat_map(fn span ->
      [
        span ++ [:start],
        span ++ [:stop],
        span ++ [:exception]
      ]
    end)
  end
end
