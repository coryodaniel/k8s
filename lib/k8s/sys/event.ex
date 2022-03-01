defmodule K8s.Sys.Event do
  @deprecated "Use K8s.Sys.Telemetry instead"

  @moduledoc """
  Telemetry event defimitions for this library
  """

  @spec events() :: list()
  defdelegate events, to: K8s.Sys.Telemetry
end
