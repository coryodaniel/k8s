defmodule K8s.Sys.OpenTelemetry do
  @moduledoc """
  This module is still in beta! It has not been tested well and feedback is welcome!

  Converts telemetry spans to opentelemetry tracing spans

  ### Usage

      K8s.Sys.OpenTelemetry.attach()
  """

  @doc """
  Attaches telemetry spans to the opentelemetry processor
  """
  @spec attach() :: :ok
  def attach do
    for span <- K8s.Sys.Telemetry.spans() do
      span_name = Enum.join(span, ".")

      :ok =
        :telemetry.attach(
          "k8s-otel-tracer-#{span_name}-start",
          span ++ [:start],
          &__MODULE__.handle_event/4,
          %{tracer_id: :k8s, type: :start, span_name: "k8s." <> span_name}
        )

      :ok =
        :telemetry.attach(
          "k8s-otel-tracer-#{span_name}-stop",
          span ++ [:stop],
          &__MODULE__.handle_event/4,
          %{tracer_id: :k8s, type: :stop}
        )

      :ok =
        :telemetry.attach(
          "k8s-otel-tracer-#{span_name}-exception",
          span ++ [:exception],
          &__MODULE__.handle_event/4,
          %{tracer_id: :k8s, type: :exception}
        )
    end

    :ok
  end

  @doc false
  @spec handle_event(
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          :telemetry.handler_config()
        ) :: any()
  def handle_event(
        _event,
        %{system_time: start_time},
        metadata,
        %{type: :start, tracer_id: tracer_id, span_name: name}
      ) do
    start_opts = %{start_time: start_time}
    OpentelemetryTelemetry.start_telemetry_span(tracer_id, name, metadata, start_opts)
    :ok
  end

  def handle_event(
        _event,
        %{duration: duration},
        metadata,
        %{type: :stop, tracer_id: tracer_id}
      ) do
    OpentelemetryTelemetry.set_current_telemetry_span(tracer_id, metadata)
    OpenTelemetry.Tracer.set_attribute(:duration, duration)
    OpentelemetryTelemetry.end_telemetry_span(tracer_id, metadata)
    :ok
  end

  def handle_event(
        _event,
        %{duration: duration},
        %{kind: kind, reason: reason, stacktrace: stacktrace} = metadata,
        %{type: :exception, tracer_id: tracer_id}
      ) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(tracer_id, metadata)
    status = OpenTelemetry.status(:error, inspect(reason))
    OpenTelemetry.Span.record_exception(ctx, kind, stacktrace, duration: duration)
    OpenTelemetry.Tracer.set_status(status)
    OpentelemetryTelemetry.end_telemetry_span(tracer_id, metadata)
    :ok
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
