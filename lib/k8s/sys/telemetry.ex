defmodule K8s.Sys.Telemetry do
  @moduledoc """
  Telemetry event defimitions for this library
  """

  @events [
    [:http, :request, :start],
    [:http, :request, :stop],
    [:http, :request, :exception]
  ]

  @spec events() :: list()
  def events, do: @events
end
