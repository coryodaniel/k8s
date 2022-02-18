defmodule K8s.Sys.Telemetry do
  @moduledoc false

  @events [
    [:http, :request, :start],
    [:http, :request, :stop],
    [:http, :request, :exception]
  ]

  @spec events() :: list()
  def events, do: @events
end
