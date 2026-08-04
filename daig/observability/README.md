# Observability

Four pillars, one request. This directory is the whole stack.

```
services  --OTLP-->  otel-collector  --->  Tempo        (traces)
                                     --->  Prometheus   (metrics, incl. span metrics)
services  --stdout->  Promtail       --->  Loki         (logs)
services  --push--->  Pyroscope                        (profiles)
                          all four   --->  Grafana
```

## Why the Collector is in the middle

Every service speaks OTLP and knows nothing about Tempo, Prometheus, or any
vendor. Replacing a backend is a change in `otel-collector.yaml` and nowhere
in the application code. That is the entire argument for OpenTelemetry, and it
is worth stating out loud on Day 4 because it is the reason OTel won.

## The pivot chain that makes Day 4 work

The datasource provisioning wires all of these deliberately:

1. **Metrics say something is wrong.** p95 latency crosses the 1s SLO line.
2. **Traces say where.** Click through to a slow trace; `dispatch` owns 8 of
   the 9 seconds, and inside it are 40 sequential database spans.
3. **Logs say what.** `tracesToLogsV2` jumps to the log lines for that exact
   trace id.
4. **Profiles say which line.** `tracesToProfiles` opens the flame graph for
   the span, where `computeSurgeScore` is 71% of CPU.

Four questions, one request, four clicks. Walk that chain live and the four
pillars stop being a list to memorise.

## Prometheus here, Mimir in production

Prometheus is a single binary with local storage, which is right for a laptop
and wrong for a fleet. In production this slot is Mimir: same query language,
same dashboards, horizontally scalable, multi-tenant, long retention. Nothing
in this repo changes except the remote-write target - which is the point of
keeping the Collector in the middle.

## Cardinality, said once so it lands

`daig_http_request_duration_seconds` is labelled by service, method, route and
status. It is **not** labelled by order id, customer area, or user.

A label with a thousand values makes a thousand time series per metric. Interns
reliably try to add an order id label on Day 4. Let them, then show them the
series count, then remove it. It is a five-minute lesson that saves a real
incident later.
