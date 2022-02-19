defmodule K8s.Sys.Logger do
  @moduledoc "Attaches telemetry events to the Elixir Logger"

  require Logger

  @doc """
  Attaches telemetry events to the Elixir Logger
  """
  @spec attach() :: :ok | {:error, :already_exists}
  def attach do
    events = K8s.Sys.Telemetry.events()
    :telemetry.attach_many("k8s-events-logger", events, &__MODULE__.log_handler/4, :debug)
  end

  @doc false
  @spec log_handler(
          Telemetry.event_name(),
          Telemetry.event_measurements(),
          Telemetry.event_metadata(),
          Telemetry.handler_config()
        ) :: any()
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
      metadata(
        measurements: measurements,
        metadata: metadata
      )
    )
  end

  @spec metadata(keyword()) :: keyword()
  def metadata(meta \\ []) do
    Keyword.merge(meta, library: :k8s)
  end
end
