defmodule K8s.Sys.Spandex do
  @moduledoc """
  This module is still in beta! It has not been tested well and feedback is welcome!

  Converts telemetry spans to Spandex tracing spans.

  ### Usage

      K8s.Sys.Spandex.attach(MyApp.Tracer)
  """

  require Spandex

  @spec attach(atom()) :: :ok
  def attach(tracer) do
    for span <- K8s.Sys.Telemetry.spans() do
      span_name = Enum.join(span, ".")

      :ok =
        :telemetry.attach(
          "k8s-spandex-tracer-#{span_name}-start",
          span ++ [:start],
          &__MODULE__.handle_event/4,
          %{tracer: tracer, type: :start, span_name: "k8s." <> span_name}
        )

      :ok =
        :telemetry.attach(
          "k8s-spandex-tracer-#{span_name}-stop",
          span ++ [:stop],
          &__MODULE__.handle_event/4,
          %{tracer: tracer, type: :stop}
        )

      :ok =
        :telemetry.attach(
          "k8s-spandex-tracer-#{span_name}-exception",
          span ++ [:exception],
          &__MODULE__.handle_event/4,
          %{tracer: tracer, type: :exception}
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
        %{system_time: _start_time},
        metadata,
        %{type: :start, tracer: tracer, span_name: name}
      ) do
    tracer.start_span(name, service: :k8s, type: :custom, tags: Map.to_list(metadata))
    :ok
  end

  def handle_event(
        _event,
        %{duration: _duration},
        metadata,
        %{type: :stop, tracer: tracer}
      ) do
    tracer.update_span(tags: Map.to_list(metadata))
    tracer.finish_span() |> IO.inspect()
    :ok
  end

  def handle_event(
        _event,
        %{duration: _duration},
        %{kind: kind, reason: reason, stacktrace: stacktrace} = metadata,
        %{type: :exception, tracer: tracer}
      ) do
    metadata =
      metadata
      |> Map.put(:error, reason)
      |> Map.delete(:reason)

    tracer.span_error(kind, stacktrace, error: reason, tags: metadata)
    :ok
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
