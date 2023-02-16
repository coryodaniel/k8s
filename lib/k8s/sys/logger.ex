defmodule K8s.Sys.Logger do
  @moduledoc "Attaches telemetry events to the Elixir Logger"

  require Logger

  defmacro log_prefix(stmt) do
    prefix = __CALLER__.module |> Module.split() |> Enum.join(".")
    prefix = prefix <> " "

    quote do
      unquote(prefix) <> unquote(stmt)
    end
  end

  @doc """
  Attaches telemetry events to the Elixir Logger
  """
  @spec attach() :: :ok
  def attach do
    events = K8s.Sys.Telemetry.events()
    :telemetry.attach_many("k8s-events-logger", events, &__MODULE__.log_handler/4, :debug)
  end

  @doc false
  @spec log_handler(keyword, map | integer, map, atom) :: :ok
  def log_handler(event, measurements, metadata, preferred_level) do
    event_name = Enum.join(event, ".")

    level =
      case Regex.match?(~r/fail|error/, event_name) do
        true -> :error
        _ -> preferred_level
      end

    Logger.log(
      level,
      "TELEMETRY: #{event_name}",
      library: :k8s,
      measurements: measurements,
      metadata: metadata
    )
  end
end
