# Cost — running the rotation on AWS, GCP and Azure

Every number here is computed by `scripts/cost-model.py`, not typed. Change a
rate in the `PRICES` table, rerun, and the whole model updates.

```bash
python3 scripts/cost-model.py
python3 scripts/cost-model.py --interns 25 --days 6
```

Rates verified against public sources in August 2026 where marked `[V]` in the
script; the rest are marked `[E]` and **must** be confirmed against the official
calculators before anyone commits budget. US regions; EU and APAC run 8–30%
higher. Excludes tax. All monthly figures derive from **730 hours/month**.

---

## The headline

**Roughly $5–9 per cloud for the whole rotation, if you run it properly.**

That number surprises people who expect hundreds. The reason is structural, and
it is the most useful thing on this page:

> **Cloud is only needed on 2 of the 6 days.**

| Day | Topic | Cloud needed? |
|---|---|---|
| 1 | Git, Linux, networking | No — local Docker |
| 2 | Cloud + Terraform | **Yes** — full stack, ~8h |
| 3 | Ansible + Docker | No — local |
| 4 | CI/CD + observability | No — local, plus GitHub Actions |
| 5 | DevSecOps | No — local |
| 6 | Kubernetes + Demo Day | **Yes** — one shared cluster, ~8h |

Sixteen billable hours across a six-day rotation. Everything else runs on the
interns' laptops, which is deliberate — see NFR-41 in `docs/REQUIREMENTS.md`.

---

## Cost per hour, while a stack exists

The application stack: three services, managed Postgres, load balancer, registry,
secret store.

| | AWS | GCP | Azure |
|---|---|---|---|
| Compute | $0.0395 Fargate (4 tasks, ARM) | $0.0909 Cloud Run (1 warm) | $0.0936 Container Apps |
| Managed Postgres | $0.0160 + $0.0032 storage | $0.0123 + $0.0047 storage | $0.0164 + $0.0050 storage |
| Load balancer / ingress | $0.0305 ALB | included | included |
| NAT / connector | $0.0450 NAT Gateway | $0.0200 VPC connector | included |
| Public IPv4 | $0.0150 (3 addresses) | — | — |
| Registry | $0.0002 ECR | $0.0002 Artifact Registry | $0.0068 ACR Basic |
| Secrets | $0.0011 Secrets Manager | negligible | negligible |
| **Total per hour** | **$0.1504** | **$0.1281** | **$0.1219** |
| Per 8-hour day | $1.20 | $1.02 | $0.98 |
| Per 24-hour day | $3.61 | $3.07 | $2.93 |

**The three clouds are within about 20% of each other**, and the spread is
smaller than the error bars on the `[E]` estimates. Anyone telling you one
hyperscaler is dramatically cheaper for this shape of workload is selling
something. What differs is discount structure, networking topology, and how each
handles idle — not list price.

---

## Scenarios — 20 interns, 6 days

| Scenario | AWS | GCP | Azure |
|---|---|---|---|
| **1 · Recommended** — shared stack, cloud only when needed | **$5.33** | **$4.31** | **$8.83** |
| 2 · Shared stack left running all week, 24h | $29.35 | $25.11 | $29.20 |
| 3 · Per-intern stacks on Day 2 | $72.85 | $54.18 | $140.50 |
| 4 · Per-intern stacks forgotten for 30 days | $2,196 | $1,870 | $1,780 |

**Scenario 4 is 412× scenario 1 on AWS for exactly the same teaching outcome.**

The dominant cost variable is not the cloud, the region, or the instance size. It
is whether anyone runs `terraform destroy`. Put it in the Day 2 checklist, and put
a budget alert on the account before the first `apply`.

### Why Azure is highest in scenario 1 despite the cheapest stack

Log Analytics ingestion at **$2.76/GB** — roughly five times CloudWatch. Two
gigabytes of logs from the observability exercise costs $5.52, which on a $9
rotation is most of the bill.

Cap the daily quota on the workspace. It is one setting and it is the difference
between Azure being cheapest and Azure being most expensive here.

---

## Budget recommendation

| Cloud | Likely spend | Set the alert at |
|---|---|---|
| AWS | $17.60 | **$45** |
| GCP | $14.79 | **$35** |
| Azure | $21.39 | **$55** |

"Likely" assumes the recommended pattern plus one forgotten weekend plus one
intern who applies their own stack twice. Both will happen.

The alert sits at roughly 2.5× likely spend deliberately. **An alert that fires
during normal usage gets muted, and a muted alert is worse than no alert.** Set
it before the first `terraform apply`, not after.

If you go hands-on with only one cloud — which `docs/COVERAGE.md` recommends —
budget for one, not three.

---

## Findings worth acting on

### 1. AKS gives you the Kubernetes control plane free

| | Control plane |
|---|---|
| AWS EKS | $0.10/hr — $73/month, no free tier |
| GCP GKE Standard | $0.10/hr (Autopilot waives it, adds a per-pod surcharge) |
| **Azure AKS** | **$0** |

For one 8-hour Day 6 that is $0.80 versus nothing — trivial. But if you leave a
teaching cluster up between cohorts, it is $73/month per cluster on AWS and free
on Azure. If the Kubernetes day is the only cloud you use, Azure is the obvious
host.

### 2. The model already changed the infrastructure once

All three Cloud Run services originally had `min_instances = 1` with
`cpu_idle = false`, which means CPU is always allocated. GCP came out at
**$0.31/hr — more expensive than the Fargate stack** — because that configuration
discards the single thing Cloud Run is good at.

`kitchen` and `dispatch` now scale to zero; `orders` stays warm because it is the
public entry point and a cold start on the first request of a demo looks bad.
That cut GCP from $0.31/hr to $0.128/hr — a **59% reduction from one variable**.

See the `COST NOTE` in `infra/gcp/variables.tf`. This is the FinOps loop working
as intended: model, find, fix, remodel. Worth showing interns as a worked example,
because it is a real finding in real code rather than a hypothetical.

### 3. On AWS you pay rent before anything runs

NAT Gateway plus three public IPv4 addresses: **$0.0600/hr — $43.80/month** with
zero containers running and zero traffic.

Since February 2024 every public IPv4 address costs $0.005/hr whether attached,
unattached, or idle. This is the most common source of surprise on a training
account and none of it appears under a service name you would think to check.

### 4. GitHub Actions is probably free, and check anyway

Public repository → unlimited minutes. Private → 2,000 minutes/month on Free,
3,000 on Team. The seven-gate DevSecOps pipeline takes roughly 12–15 minutes per
run; twenty interns pushing a few times a day for a week fits comfortably inside
either allowance.

The one to watch is the `integration` job, which brings the whole compose stack up
on a runner. It is the slowest job by a wide margin.

### 5. Interns will forget. Design for it.

- `terraform destroy` in the Day 2 **and** Day 6 checklists, verified by the
  instructor before anyone leaves
- Budget alert at the numbers above, set before the first apply
- A scheduled teardown job — a nightly `terraform destroy` in CI on the training
  account costs nothing and has saved more money than any rightsizing exercise
- Tag everything with a cost centre. `infra/` does this via `default_tags` /
  `default_labels`, and there is an OPA policy that fails the plan if a resource
  is untagged.

---

## What is *not* in these numbers

| Excluded | Why |
|---|---|
| Tax / GST | Varies by billing entity; Pakistan-based billing differs from US |
| Free-tier credits | Beyond the Container Apps grant, deliberately ignored — a new account may pay far less |
| Support plans | AWS Developer support is $29/month minimum, which would double a $17 bill |
| SonarQube | Community edition, self-hosted, free |
| Interns' laptops | Days 1, 3, 4 and 5 run entirely local |
| Data egress beyond 5GB | Modelled at 5GB; a runaway load test changes this |

That support-plan row is worth noting: **on a bill this small, the support plan
costs more than the infrastructure.** Use an existing organisational account
rather than opening a new one for training.

---

## Verify before you commit

- AWS — https://calculator.aws
- GCP — https://cloud.google.com/products/calculator
- Azure — https://azure.microsoft.com/pricing/calculator

Rates marked `[E]` in `scripts/cost-model.py` are estimates from published
secondary sources, not from the vendors' APIs. The `[V]` rates were confirmed in
August 2026. Cloud pricing moves; the model is built to be updated rather than
trusted indefinitely.

**Per this repository's own discipline: these figures are computed, not verified
against an actual invoice.** Run the rotation once, compare the real bill to this
model, and correct the `PRICES` table. That comparison is the most valuable FinOps
exercise available and it costs nothing but attention.
