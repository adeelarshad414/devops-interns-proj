# Instructor notes

**Interns should not read this file.** It contains the answers.

---

## Before Monday - the half day you must actually spend

Nothing in this repository has been executed. See `VERIFICATION.md` for the
precise split between what has been syntax-checked and what has only been
written. Budget half a day and work in this order:

1. `cp .env.example .env && make up` — expect to fix npm or OTel package
   versions. The JS OpenTelemetry packages churn faster than any other part of
   this stack and the version pins here are a best guess.
2. `make seed && make smoke` — all tiers green.
3. `make broken` then `docker run tkxel/daig-orders:broken` — **this one is
   non-negotiable.** It is the kickoff exercise. Confirm the log line names
   `DATABASE_URL` and the exit code is 78.
4. `make obs` — confirm a trace crosses all three services in Tempo, and that
   clicking from trace to logs and profiles works.
5. `PROFILE=spike node load/iftar-spike.js` with `./chaos/day4-latency.sh break`
   — confirm p95 visibly breaches the 1s SLO line on the dashboard.
6. `cd infra/aws && terraform init && terraform validate` — expect provider
   argument changes.

If you only have two hours, do steps 1, 3 and 4. Those cover the kickoff and
Day 4, which are the two sessions that fail hardest if the demo does not work.

---

## Answers to the chaos exercises

### Day 1 — network

| Variant | Cause | Tell |
|---|---|---|
| 1 | `/etc/hosts` poisoned with a bogus address for `postgres` | `getent hosts postgres` returns 10.255.255.1; DNS resolves but nothing answers |
| 2 | iptables DROP on outbound 5432 | `getent hosts` fine, `nc -zv` hangs rather than refusing — a **hang** means dropped, a **refusal** means nothing listening |
| 3 | Connection string points at port 5433 | Immediate connection refused; the port in the error message is the giveaway |

The hang-versus-refuse distinction is the most transferable thing on Day 1.
Make sure it gets said out loud.

### Day 3 — crash loop

| Variant | Cause | Exit code | Tell |
|---|---|---|---|
| 1 | No `DATABASE_URL` | 78 | Log names the variable |
| 2 | Wrong password | 0 then unhealthy | Starts, `/readyz` 503, auth error in logs |
| 3 | `PORT=1` | non-zero | EACCES — ports below 1024 need privilege, and the container runs as non-root |

### Day 4 — latency

Two independent defects, deliberately:

- **`dispatch`** — `CHAOS_SLOW_DISPATCH=true` switches `pickRider()` to an N+1:
  one query for riders, then one per rider. Visible in **traces** as dozens of
  sequential `count_rider_load` spans. Fixed by the commented-out index in
  `db/init/001_schema.sql` plus the grouped query that is already in the code.
- **`kitchen`** — `CHAOS_HOT_SURGE_LOOP=true` switches `computeSurgeScore()` to
  an O(n²) nested loop. Invisible in traces (it is CPU inside one span) and
  obvious in **profiles**.

The pedagogical point: one defect is only findable with traces, the other only
with profiles. Neither is findable with metrics alone. That is why four pillars
exist, and this exercise is the proof.

### Day 5 — Demo Day

| # | Cause | Fastest tell |
|---|---|---|
| 1 | Image tag does not exist | `describe` → ImagePullBackOff |
| 2 | Secret key renamed | `describe` → CreateContainerConfigError names the key |
| 3 | Memory limit 16Mi | `describe` → last state OOMKilled |
| 4 | Readiness probe wrong port | Running but 0/1 Ready; probe failure in events |
| 5 | Service selector typo | `get endpoints` is empty — the single fastest check in Kubernetes |
| 6 | Replicas 0 | No pods at all, no errors anywhere. Hardest to spot because nothing is broken |
| 7 | ConfigMap wrong host | Exit 78 in `logs --previous` |
| 8 | CPU limit 50m | Pods healthy, latency terrible. Only metrics reveal it |
| 9 | NetworkPolicy denies egress | Readiness 503 and **nothing in any log explains why** |

Scenario 6 and 9 are the two hardest, for opposite reasons: 6 has no error, 9
has an error with no cause. Save them for whoever is clearly ahead.

---

## Pacing

| Day | Risk | Lever |
|---|---|---|
| 1 | Runs short if they are already comfortable | Add a second chaos variant per team |
| 2 | Cloud account problems eat the morning | Have credentials tested Friday before |
| 3 | Runs long — two topics | Cut image-shrinking, keep layer caching |
| 4 | **Overloaded** | Pre-built pipeline, they add one stage |
| 5 | Demo Day overruns with >20 interns | Run heats, or pair them |

---

## Things to say out loud, that are easy to forget

- **Day 2:** console first is deliberate. Say so, or it reads as wasted time.
- **Day 3:** Chef and Puppet are legacy. They will see the names and deserve to
  know where they sit.
- **Day 4:** an optimisation you did not measure did not happen.
- **Day 5:** you will not know Kubernetes tonight. Protecting them from
  overclaiming in an interview is a real kindness.
- **Every day:** `terraform destroy` before they leave. Set a budget alert
  before the first apply, not after.
- **Demo Day, on Monday, not Friday:** a well-reasoned failure beats a lucky
  guess. If they only hear this on Friday morning it produces panic instead of
  thinking.

---

## Cost control

- Budget alert on the training account **before** the first `apply`.
- The standing charges are managed Postgres, the NAT gateway (AWS), the VPC
  connector (GCP), and the Container Apps environment (Azure). They bill whether
  or not anyone touches Daig.
- All monthly figures in this repo derive from **730 hours/month**. Use that
  constant consistently or your numbers will not reconcile with the invoice.
- A `terraform destroy` at 17:00 daily is worth more than any amount of
  instance-size optimisation.
