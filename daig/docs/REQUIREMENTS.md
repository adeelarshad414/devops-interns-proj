# Requirements

Functional and non-functional requirements with IDs, so that a test, a
dashboard panel or a policy can cite the thing it enforces.

Status values: **Implemented** · **Partial** · **Not built** · **Deliberately
absent**

> Implemented means the code exists and was reviewed. It does **not** mean it was
> executed. See `VERIFICATION.md` — nothing in this repository has been run.

---

## Functional requirements

### Ordering

| ID | Requirement | Acceptance criteria | Status |
|---|---|---|---|
| **FR-1** | List restaurants with availability | `GET /api/restaurants` returns every restaurant with `is_open` and a count of available items | Implemented |
| **FR-2** | List a restaurant's menu | `GET /api/restaurants/:id/menu` returns items with `price_paisa` and `is_available` | Implemented |
| **FR-3** | Place an order | `POST /api/orders` with `restaurant_id`, `customer_area` and a non-empty `items` array returns 201 and an `order_id` | Implemented |
| **FR-4** | Reject an unavailable item | An order containing an unavailable `menu_item_id` returns 422 and commits nothing | Implemented |
| **FR-5** | Compute the total | `total_paisa` equals the sum of `price_paisa × qty`, in integers only | Implemented |
| **FR-6** | Retrieve an order with its history | `GET /api/orders/:id` returns the order and its `order_events`, oldest first | Implemented |
| **FR-7** | Order ownership check | An order is readable only by the customer who placed it | **Deliberately absent** — this is VULN-2, the exercise |

### Kitchen

| ID | Requirement | Acceptance criteria | Status |
|---|---|---|---|
| **FR-8** | Accept or reject | `POST /api/kitchen/accept` sets `ACCEPTED` if the restaurant is open, `REJECTED` otherwise | Implemented |
| **FR-9** | Surge multiplier | Returns a multiplier between 1.0 and 2.5 based on open orders per area | Implemented |
| **FR-10** | Report prep time | The response includes the restaurant's `prep_minutes` | Implemented |

### Dispatch

| ID | Requirement | Acceptance criteria | Status |
|---|---|---|---|
| **FR-11** | Assign a rider | `POST /api/dispatch/assign` selects the least-loaded on-shift rider in the customer's area | Implemented |
| **FR-12** | Handle no rider | Returns 409 with the area named when no rider is available | Implemented |
| **FR-13** | Rider overview | `GET /api/dispatch/riders` returns every rider with their active assignment count | Implemented |

### State and data integrity

| ID | Requirement | Acceptance criteria | Status |
|---|---|---|---|
| **FR-14** | Valid states only | A `CHECK` constraint rejects any state outside the enumerated set | Implemented |
| **FR-15** | Append-only history | Every transition inserts an `order_events` row; no row is ever updated or deleted | Implemented |
| **FR-16** | Durable before best-effort | The order transaction commits before any downstream HTTP call | Implemented |
| **FR-17** | Survive downstream failure | A kitchen or dispatch failure leaves a retryable order, not a lost one | Implemented |

### Platform

| ID | Requirement | Acceptance criteria | Status |
|---|---|---|---|
| **FR-18** | Liveness probe | `/healthz` returns 200 whenever the process is running, with no database call | Implemented |
| **FR-19** | Readiness probe | `/readyz` returns 503 when the database is unreachable | Implemented |
| **FR-20** | Metrics endpoint | `/metrics` exposes Prometheus text format | Implemented |
| **FR-21** | Distributed trace | One customer request produces one trace spanning web, orders, kitchen, dispatch and Postgres | Implemented |
| **FR-22** | Correlated logs | Every log line carries `trace_id` and `span_id` when a span is active | Implemented |
| **FR-23** | Credentials from a vault | Services resolve credentials from OpenBao via AppRole | Implemented |
| **FR-24** | Fail closed | A configured-but-unreachable vault causes exit 78, never a silent fallback | Implemented |
| **FR-25** | Dynamic credentials | With `BAO_DYNAMIC_DB=true`, a per-request database user with a TTL is minted | Implemented |
| **FR-26** | Load shedding | With `CHAOS_DROP_RATE>0`, a proportion of orders are rejected with 503 | Implemented |
| **FR-27** | Authentication | — | **Not built.** Deliberate: this is a teaching artifact, never deployed. |
| **FR-28** | Payment processing | — | **Not built.** Modelled as an external dependency only. |

---

## Non-functional requirements

### Reliability

| ID | Requirement | Target | How it is enforced or measured | Status |
|---|---|---|---|---|
| **NFR-1** | Availability SLO | 99.9% of order requests over 30 days (**43 min/month**) | `daig:order_availability:ratio5m`, `observability/rules/slo.yml` | Implemented |
| **NFR-2** | Latency SLO | p95 of `POST /api/orders` under 1s | `daig:order_latency:p95_5m` + `DaigOrdersSlow` alert | Implemented |
| **NFR-3** | Error budget policy | Above 75% consumed, consider a change freeze | `DaigErrorBudgetBurning` alert | Implemented |
| **NFR-4** | Graceful degradation | Shed load rather than collapse under the iftar spike | `CHAOS_DROP_RATE`; `load/iftar-spike.js` measures it | Partial — shedding is manual, not adaptive |
| **NFR-5** | Startup | Ready within 30s | `startupProbe` `failureThreshold: 30`, `periodSeconds: 2` | Implemented |
| **NFR-6** | Graceful shutdown | Drain in-flight requests on SIGTERM | `server.close()` then `pool.end()` | Implemented |
| **NFR-7** | No single pod takes the service down | `maxUnavailable: 0`, PDB `minAvailable: 1` | `k8s/base/*.yaml` | Implemented |

### Performance and scale

| ID | Requirement | Target | Notes | Status |
|---|---|---|---|---|
| **NFR-8** | Iftar spike | Survive 100× baseline for 20 minutes | Scheduled pre-scale plus reactive autoscaling | Implemented (untested) |
| **NFR-9** | Scale-out speed | Double capacity within 15s of breaching 60% CPU | HPA `scaleUp` 100%/15s, stabilisation 0 | Implemented |
| **NFR-10** | Scale-in caution | No more than 25% reduction per minute, after 5 min stable | HPA `scaleDown` behaviour | Implemented |
| **NFR-11** | Connection pooling | Maximum 10 connections per instance | `PG_POOL_MAX` | Implemented |
| **NFR-12** | Metric cardinality | No label with unbounded values | Labels limited to service, method, route, status | Implemented |

### Security

| ID | Requirement | Target | Notes | Status |
|---|---|---|---|---|
| **NFR-13** | No credential in code | Zero real secrets in the repository | `CHANGE_ME_DEV_ONLY` + CI grep + gitleaks + pre-commit hook | Implemented |
| **NFR-14** | No credential in environment in production | Vault only | `secrets.js` exits 78 without a vault when `NODE_ENV=production` | Implemented |
| **NFR-15** | Least privilege | Each service reads only its own secrets | Four policies in `vault/policies/` | Implemented |
| **NFR-16** | Credential audit trail | Every secret read logged with identity and timestamp | OpenBao audit device, enabled before any write | Implemented |
| **NFR-17** | Non-root containers | Every container | `USER daig`; `runAsNonRoot: true` | Implemented |
| **NFR-18** | Read-only root filesystem | Every application container | `readOnlyRootFilesystem: true` + `/tmp` emptyDir | Implemented |
| **NFR-19** | Capabilities dropped | `drop: [ALL]` | `k8s/base/*.yaml` | Implemented |
| **NFR-20** | No public database | Private subnets only | Security groups, `publicly_accessible = false`, private IP | Implemented |
| **NFR-21** | Encryption at rest | All managed databases | `storage_encrypted = true` and equivalents | Implemented |
| **NFR-22** | Encryption in transit | TLS everywhere | **Partial** — deliberately absent on the ALB; TODO in `loadbalancer.tf` |
| **NFR-23** | Image scanning | Build fails on HIGH/CRITICAL | Trivy with `exit-code: 1` | Implemented |
| **NFR-24** | SBOM | Every image | syft, CycloneDX, attached as a cosign attestation | Implemented |
| **NFR-25** | Signed images | Every image, keyless | cosign via GitHub OIDC | Implemented |
| **NFR-26** | Unsigned images refused | Admission denied | Kyverno `verifyImages` — currently `Audit`, move to `Enforce` when green | Partial |
| **NFR-27** | Immutable tags | A tag always means the same image | ECR `IMMUTABLE`; Artifact Registry `immutable_tags` | Implemented |

### Operability

| ID | Requirement | Target | Notes | Status |
|---|---|---|---|---|
| **NFR-28** | Structured logs | JSON to stdout, one object per line | pino | Implemented |
| **NFR-29** | Log rotation | 10MB × 3 files per container | Compose `logging` and Docker daemon config | Implemented |
| **NFR-30** | Deploy marker | Every dashboard shows when a deploy happened | **Not built** — TODO in `cd.yml`. Half of incident diagnosis is "what changed and when". |
| **NFR-31** | Rollback | One step, no rebuild, under 2 minutes | ECS circuit breaker, `kubectl rollout undo`, Swarm `failure_action: rollback` | Implemented |
| **NFR-32** | Deploy window guard | No deploys 16:00–21:00 PKT | `cd.yml` guard job | Implemented |
| **NFR-33** | Alert on symptoms | Never alert on causes | Four alerts, all customer-visible symptoms | Implemented |
| **NFR-34** | Runnable by anyone | `make help` lists every workflow | Self-documenting Makefile | Implemented |

### Maintainability and cost

| ID | Requirement | Target | Notes | Status |
|---|---|---|---|---|
| **NFR-35** | Additive schema only | No destructive migration, ever | Convention, stated in `db/init/001_schema.sql` and `CONTRIBUTING.md` | Implemented |
| **NFR-36** | Reproducible builds | Pinned base images, multi-stage, no `:latest` | Dockerfiles + OPA policy that blocks `:latest` | Implemented |
| **NFR-37** | Cost attribution | Every cloud resource tagged with a cost centre | `default_tags` / `default_labels` + OPA policy | Implemented |
| **NFR-38** | Cost derivation constant | All monthly figures from **730 hours/month** | Stated in `infra/README.md` and every cost output | Implemented |
| **NFR-39** | Honest verification status | Execution status tracked per area | `VERIFICATION.md` | Implemented |

### Teaching

These are real constraints. They are the reason for several decisions that would
otherwise look like under-engineering.

| ID | Requirement | Target | Status |
|---|---|---|---|
| **NFR-40** | Comprehensible | An intern can hold the whole architecture in their head by day six | Implemented — drove "three services, no build step" |
| **NFR-41** | Laptop-runnable | Base stack under 2GB RAM; overlays separate | Implemented |
| **NFR-42** | Every defect labelled in place | At the point of definition, not only in docs | Implemented |
| **NFR-43** | Every defect teaches something distinct | No two defects diagnosed the same way | Implemented |
| **NFR-44** | Zero-dependency load generator | Runs before anything is installed, offline | Implemented |
| **NFR-45** | Instructor material separated | Answers only in `docs/INSTRUCTOR.md` | Implemented |

---

## Traceability

Which requirement each teaching artifact exercises:

| Artifact | Exercises |
|---|---|
| `chaos/day1-network.sh` | FR-19, NFR-20 |
| `chaos/day2-drift.sh` | NFR-35, NFR-37 |
| `chaos/day3-crashloop.sh` | FR-24, NFR-13 |
| `chaos/day4-latency.sh` | NFR-2, NFR-8, FR-21 |
| `chaos/day5-demoday.sh` | FR-18, FR-19, NFR-7, NFR-31 |
| `chaos/day6-security.sh` | FR-7, NFR-13, NFR-23 |
| `load/iftar-spike.js` | NFR-1, NFR-2, NFR-4, NFR-8 |
| `security/scan-all.sh` | NFR-13, NFR-23, NFR-24 |
| `security/sign-and-verify.sh` | NFR-24, NFR-25, NFR-26 |
| `vault/bootstrap.sh` | NFR-14, NFR-15, NFR-16 |
| `vault/demo.sh` | FR-25, NFR-15, NFR-16 |

**FR-7 is the interesting row.** It is the only requirement deliberately *not*
implemented, and the only one no scanner can detect as missing. That is the
DevSecOps day in one line.
