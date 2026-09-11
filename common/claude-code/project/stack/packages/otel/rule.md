# Observability: @effect/opentelemetry

One tracing layer in the application's main layer (`src/main.ts`), exporting
OTLP to wherever `OTEL_EXPORTER_OTLP_ENDPOINT` points. Spans come from
`Effect.withSpan` on service methods, logs from `Effect.log*`, metrics from
`Metric`. No Sentry SDK, no pino, no winston, no `console.log` in code the
runtime runs.

API: `repos/effect/packages/opentelemetry/`.
