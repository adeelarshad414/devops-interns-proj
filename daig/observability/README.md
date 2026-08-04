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

## Alerting has a delivery path now

`prometheus.yml` has an `alerting:` block and the obs overlay ships an
**Alertmanager** (`alertmanager.yml`). Without it, rules evaluate and go FIRING
in the Prometheus UI but reach nobody — a common and dangerous half-measure.
Routing is by **severity**: `critical` → a pager receiver, `warning` → a
ticket/Slack receiver. The receivers are intentionally empty so the container
starts without secrets; fill in the PagerDuty routing key / Slack webhook where
the placeholders are.

## Error budgets: burn rate, not a single threshold

`rules/slo.yml` now carries **multi-window, multi-burn-rate** alerts (the Google
SRE workbook pattern). Each pairs a long window ("this is real") with a short
one ("it's still happening"): fast burn (14.4× over 1h & 5m) pages; slow burn
(6× over 6h & 30m) pages; a 3× over 24h & 2h burn opens a ticket. The old single
"75% of budget consumed" rule is kept only as a change-freeze signal — it is a
lagging total, not a pager.

Two supporting config points make the budget math honest:

- Prometheus retention is **31d** (was 24h) so a 30-day budget window actually
  has 30 days of data.
- `--web.enable-remote-write-receiver` accepts Tempo's generated service-graph/
  span metrics, and `--enable-feature=exemplar-storage` keeps exemplars so the
  metrics → trace pivot below actually works.

## Cardinality, said once so it lands

`daig_http_request_duration_seconds` is labelled by service, method, route and
status. It is **not** labelled by order id, customer area, or user.

A label with a thousand values makes a thousand time series per metric. Interns
reliably try to add an order id label on Day 4. Let them, then show them the
series count, then remove it. It is a five-minute lesson that saves a real
incident later.
