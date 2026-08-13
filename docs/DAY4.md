# Day 4 - CI/CD & Observability

> **Daig chapter:** Ship it without touching it. Then see what you actually
> shipped.

The heaviest day. Watch the clock. If you are behind at lunch, use the de-scope
lever in the CI section.

## Morning - CI/CD

Read `.github/workflows/ci.yml` first, then make it fail on purpose.

```bash
# Break a test
vim services/orders/test/health.test.js     # change 78 to 79
git commit -am "test: deliberately break the paisa assertion"
git push
```

Watch the pipeline refuse to deploy.

**That refusal is the most valuable thing a pipeline does.** Remember the
CrowdStrike outage from Monday: their code shipped to every machine on earth
with no gate that could say no. You just built the gate.

### The four stages, and what each one is for

| Stage | Catches |
|---|---|
| `static` | Syntax, stray secrets, malformed YAML |
| `test` | Logic that used to work and no longer does |
| `build` | An image that cannot even be assembled |
| `integration` | Three services that each boot but cannot talk to each other |

The last one matters most and is the one people skip. Every service passing its
own tests tells you nothing about whether they work together.

### Security gates belong here, not in a separate week

Once the pipeline exists, add gates to it. Same mechanism as a failing test,
different assertion:

```bash
./security/scan-all.sh secrets     # ~20 seconds
./security/scan-all.sh sast        # ~2 minutes
```

Read `.github/workflows/devsecops.yml` and note the **order**: cheapest and
fastest first. A leaked key must never merge and takes 20 seconds to catch, so
it is gate 1. DAST needs the whole stack up, so it is gate 6.

The reason that ordering matters: if a developer waits twelve minutes to learn
about a typo, they stop trusting the pipeline — and a pipeline people work
around protects nobody.

Full treatment in `docs/DEVSECOPS.md`. If you have a sixth day, that is where
it goes.

### De-scope lever

If you are behind: do not author a pipeline from scratch. Take the existing one
and add **one** stage. Half of this done properly beats all of it done badly.

## Afternoon - Observability

```bash
make obs      # Grafana on :3000, admin / CHANGE_ME_DEV_ONLY
make seed
PROFILE=curve node load/iftar-spike.js
```

Open the **Daig - SLO and the four pillars** dashboard and watch the iftar
curve arrive.

### Four questions about one request

| Pillar | Question | Where |
|---|---|---|
| **Metrics** | How often, how bad, trending which way? | Prometheus panels |
| **Traces** | *Where* in the chain did it go wrong? | Tempo panel |
| **Logs** | What exactly happened? | Loki panel |
| **Profiles** | Which *line of code* is burning CPU? | Pyroscope |

Not four products. Four questions - and the same single request can answer all
four. That framing is the entire lesson.

## Chaos Hour - 16:00

```bash
./chaos/day4-latency.sh break
PROFILE=spike node load/iftar-spike.js
```

Daig is slow at iftar. Nobody tells you which service.

**Walk the pivot chain. Do not read code until step 4.**

1. **Metrics.** p95 crosses the 1s SLO line. All you know: orders is slow.
2. **Traces.** Click a slow trace. `dispatch` owns 8 of the 9 seconds — and
   inside it are dozens of sequential database spans, stacked end to end.
   That shape *is* an N+1 query.
3. **Logs.** Click from the trace straight to that request's log lines.
4. **Profiles.** Open the flame graph for the kitchen span.
   `computeSurgeScore` is most of the CPU. Now read the code, and the nested
   loop is obvious.

Two independent defects, found in four clicks, without guessing once.

### The fixes

```sql
-- 1. the missing index (db/init/001_schema.sql has it commented out)
CREATE INDEX idx_assignments_order ON assignments(order_id);
```

```bash
# 2. the fast paths already exist in the code - find the env flags that
#    switch them, then measure again
./chaos/day4-latency.sh fix
PROFILE=spike node load/iftar-spike.js
```

**Screenshot p95 before and after. The delta is your deliverable.** An
optimisation you did not measure did not happen.

## Skip this day and

You ship blind and debug by guessing. Both get more expensive every year of
your career.
