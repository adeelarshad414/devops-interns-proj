# Architecture

Design decisions and the tradeoffs behind them. Every entry answers *why this and
not the obvious alternative*, because a decision without its rejected
alternatives is not a decision, it is a preference.

---

## 1. Why three tiers, and only three services

Three tiers is the smallest structure that makes the boundary *real*: a
presentation layer that cannot reach the database, an application layer that can,
and a data layer that initiates nothing.

**Rejected: a monolith.** Simpler to run, but there is no network boundary to
misconfigure, no service-to-service call to trace, and no distributed failure to
diagnose. Half the curriculum disappears.

**Rejected: eight microservices.** More realistic for a large employer, and it
breaks NFR-12 — an intern must be able to hold the whole system in their head by
day six. Eight services means they spend the week learning the map instead of the
concepts.

Three services with one call chain (`orders → kitchen → dispatch`) is the minimum
that produces a genuinely multi-hop trace.

---

## 2. Why the frontend has no build step

`services/web` is nginx serving static HTML, CSS and vanilla JavaScript.

**Rejected: React with Vite.** More realistic, and tkxel is a React shop. It also
adds `npm ci` and `npm run build` to the critical path of every Day 2 morning. A
transitive dependency breaking the build at 09:30 derails the day, and the
teaching subject is DevOps, not frontend tooling.

The swap path is documented in `services/web/Dockerfile` and is a two-stage
Dockerfile change with nothing else affected. If someone wants React later, the
cost is one file.

---

## 3. Why bootstrap and application are separate files

Every service is `src/index.js` (bootstrap) plus `src/server.js` (the app).

Credential resolution is asynchronous — it may involve a network round trip to
OpenBao — and a CommonJS module cannot `await` at the top level.

**Rejected: ESM with top-level await.** Would work, and it changes every `require`
in the repository plus the interaction with the OpenTelemetry SDK, whose
initialisation must happen before any instrumented module loads. Not worth it.

**Rejected: synchronous credential loading.** There is no non-blocking way to do
an HTTP request synchronously in Node without a subprocess.

The constraint pushed us toward separating startup from application, which is
better structure anyway. Worth pointing out to interns: a technical constraint
that improves your design is a gift, not an obstacle.

---

## 4. Why credentials fail closed

`services/_shared/secrets.js` resolves in this order:

1. OpenBao via AppRole
2. Process environment — **only when `NODE_ENV !== 'production'`**
3. Exit 78

If OpenBao is configured but unreachable, the service **exits rather than falling
back to environment variables.**

**Rejected: graceful fallback.** It sounds resilient. It means a service can
silently degrade from "secrets from the vault, audited, short-lived" to "secrets
from the environment, unaudited, permanent" because of a network blip — and
nobody notices for six months. The audit log shows no reads and everyone assumes
the vault is working.

Exit 78 (`EX_CONFIG`, from `sysexits.h`) is deliberate: it is distinguishable
from a crash, so an orchestrator's restart logic and a human reading logs can
both tell "the configuration is wrong" from "the process died".

---

## 5. Why AppRole and not a token

| | `role_id` | `secret_id` |
|---|---|---|
| Secret | No | **Yes** |
| Lifetime | Permanent | 24h |
| Lives in | Config, image, IaC | Delivered separately at deploy |

A vault token in an environment variable is exactly the problem a vault is
supposed to solve. Splitting the credential means compromising either half alone
achieves nothing.

**Rejected: a long-lived token per service.** One environment variable, and the
whole exercise becomes theatre.

**Rejected: Kubernetes auth.** The correct answer in production, and it requires a
cluster, which Days 1–5 do not have.

---

## 6. Why liveness does not touch the database

```
/healthz  → is the process alive?        no database call
/readyz   → can it serve traffic?        database call
```

A liveness probe that checks the database will fail for every instance
simultaneously when the database is slow. The orchestrator then kills every
instance, and a *degradation* becomes an *outage*.

Readiness is the right place: an instance that cannot reach its data is removed
from the load balancer but not killed, so it rejoins when the database recovers.

This distinction is one of the most common real production mistakes and takes
thirty seconds to explain once the two endpoints are side by side.

---

## 7. Why the order is committed before the downstream call

`POST /api/orders` commits the transaction, *then* calls kitchen.

The alternative — holding the transaction open across the HTTP call — means a slow
kitchen holds database locks, and the iftar spike turns into lock contention on
top of everything else.

Committing first means a kitchen failure leaves a `PLACED` order that can be
retried. The customer's order is not lost because a downstream service was
briefly unavailable.

**Deciding what is durable and what is best-effort is most of what transaction
design is.** Worth saying out loud on Day 4.

---

## 8. Why money is integer paisa

`total_paisa INT`, never a float.

Floating-point arithmetic on currency is how you end up one paisa short a million
times. There is a unit test asserting integer arithmetic, which exists to make
the rule visible rather than because the test is hard to pass.

**Rejected: `NUMERIC`.** Correct, and slower, and invites incremental drift toward
treating money as a decimal in application code. Integer minor units is the
convention that is hardest to get wrong.

---

## 9. Why `order_events` is append-only

Every state transition inserts a row. Nothing is updated, nothing is deleted.

This gives a reconstructable history of every order, which is what you need when
a customer disputes something or an incident requires knowing what happened in
what order. It is also the same discipline as `VERIFICATION.md`: an append-only
record of what actually happened beats a mutable summary of what someone believes
is true now.

Schema changes are additive only — new columns nullable or defaulted, no `DROP`,
no destructive `ALTER`. A migration that cannot be rolled back is a deployment
that cannot be rolled back.

---

## 10. Why the OTel Collector sits in the middle

Services speak OTLP and know nothing about Tempo, Prometheus, or any vendor.

Replacing a backend is a change in `observability/otel-collector.yaml` and
nowhere in the application. That is the entire argument for OpenTelemetry and it
is worth stating explicitly, because it is the reason OTel won rather than a
nice-to-have.

The `spanmetrics` connector generates RED metrics from spans, so p95 per service
exists without any additional application code.

---

## 11. Why four observability pillars and not three

Logs, metrics, traces, **profiles**.

Day 4 proves the fourth is not padding: `dispatch` has an N+1 findable *only* in
traces, and `kitchen` has an O(n²) loop findable *only* in profiles. Metrics
detect both as "orders is slow" and can distinguish neither.

Each pillar answers a different question:

| Pillar | Question |
|---|---|
| Metrics | How often, how bad, trending which way? |
| Traces | *Where* in the chain? |
| Logs | What exactly happened? |
| Profiles | Which *line*? |

---

## 12. Why cardinality is constrained deliberately

`daig_http_request_duration_seconds` is labelled by service, method, route and
status. **Not** by order id, customer area, or user.

A label with a thousand values creates a thousand time series per metric. Interns
reliably try to add an order id label on Day 4 — let them, show them the series
count, then remove it. Five minutes that prevents a real incident later.

---

## 13. Why one NAT gateway, not one per availability zone

`infra/aws/network.tf` provisions a single NAT gateway.

This is a deliberate cost decision *and* a deliberate availability compromise: if
that AZ fails, private egress stops. Three NAT gateways cost roughly three times
as much for capacity that is idle most of the time.

The comment in the file says so, and the exercise is to ask interns which they
would choose. There is no free answer, which is exactly why it is worth asking.

---

## 14. Why scaling out is fast and scaling in is slow

Both the ECS autoscaling policy and the Kubernetes HPA use an asymmetric
behaviour block: aggressive scale-out, conservative scale-in.

The iftar spike arrives in twenty seconds; new capacity takes ninety. Flapping
capacity is worse than slightly too much of it. There is also a *scheduled*
pre-scale at 13:00 UTC — because the best autoscaler cannot react to a spike that
outpaces provisioning, and for a predictable event the answer is to anticipate
rather than react.

The scheduled action carries a comment noting that a hard-coded prayer time is a
bug with a calendar fuse on it. Iftar moves; cron does not.

---

## 15. Why policy exists twice

| Layer | Tool | Catches |
|---|---|---|
| CI | Conftest / OPA | Mistakes, in the pull request, where the fix is cheap |
| Admission | Kyverno | **Bypass** — `kubectl apply` from a laptop, a vendor Helm chart, an operator |

Neither replaces the other. CI protects you from mistakes; admission control
protects you from people going around CI. The duplication is the design.

---

## 16. Why Swarm is taught before Kubernetes and then disowned

Swarm expresses desired state, service discovery, rolling updates and self-healing
in forty readable lines. Ninety minutes of Swarm makes the Kubernetes afternoon
land, because every concept then has an equivalent the intern already holds.

Then the honesty: Swarm is in maintenance, the industry standardised on
Kubernetes, and nobody should start a production platform on it in 2026.
`docs/SWARM.md` has the translation table and says this plainly.

An intern who learns Swarm and later discovers on their own that it is not where
the jobs are will reasonably wonder what else was oversold.

---

## 17. Why the deliberate vulnerabilities are gated

`services/orders/src/insecure.js` loads only when `INSECURE_MODE=true`, and calls
`process.exit(78)` if `NODE_ENV === 'production'`.

Two gates rather than one, because a single flag someone can forget is not a
control. The module is also labelled at the top of the file, in `SECURITY.md`, and
in the README defect table — three places, because whoever finds it will be
looking in only one of them.

---

## 18. Why nothing has been executed, and why that is written down

`VERIFICATION.md` states, per area, whether something has been run or merely
syntax-checked.

This is the repository's first lesson and the reason it is a document rather than
a footnote. "Verified (mock)" and "verified (real)" are different claims. A
teaching repository that blurs them teaches the opposite of what the rotation is
for — and the interns will notice, because on Friday they are graded on exactly
this distinction.

---

## Constraints that shaped everything

| Constraint | Consequence |
|---|---|
| An intern must hold it in their head by day six | Three services, no build step, one call chain |
| It must break in *interesting* ways | Defects chosen so each teaches a different diagnostic tool |
| It must run on a laptop | Compose overlays, so nothing runs everything at once |
| It must be readable | Comments explain *why*; the repo is read more than run |
| It must not become production software | No auth, plaintext by default, `SECURITY.md` says never deploy |
