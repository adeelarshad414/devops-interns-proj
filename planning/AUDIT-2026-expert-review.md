# daig — Expert Platform Audit (Cloud · DevOps · Linux · SRE · Platform Eng)

**Date:** 2026-08-05 · **Scope:** the `daig/` stack (178 files) across containers,
Kubernetes, IaC (AWS/Azure/GCP + Ansible), security/supply-chain, observability/SRE,
and CI/CD. **Method:** six domain passes reading the actual files.

> **Framing.** daig is *teaching* software with defects planted on purpose and
> annotated in place (`insecure.js`, plaintext `secret.yaml`, `tls_disable`,
> commented-out TF backends, etc.). Those are **not** counted as gaps below — they
> are called out separately so nobody "fixes" the curriculum. What follows are
> **genuine, unintended gaps** plus **enhancements**, ranked by real-world impact.

> **✅ RESOLUTION (2026-08-05).** The P0/P1/P2 genuine gaps below have been fixed
> and pushed — see the CHANGELOG `[Unreleased]` section for the itemised list and
> the component READMEs (`k8s/`, `observability/`, `infra/`, `ansible/`) for the
> documented posture. Validated with `kubectl kustomize` (28 objects),
> `docker compose config` (base + obs) and full workflow-YAML parsing. Two
> pre-existing bugs surfaced during the fix and were also corrected: an invalid
> plain scalar in `cd.yml`, and a dummy-value CI gate whose narrow allowlist
> would have failed the build. GitHub Actions are now SHA-pinned. Deliberate
> teaching defects were left untouched.

---

## Verdict

This is unusually strong work for a training substrate. The security pipeline
(gitleaks → semgrep + CodeQL → SCA → Trivy/Checkov/OPA → cosign keyless + SBOM →
ZAP DAST), the Vault/OpenBao least-privilege policies with a deliberate
no-silent-fallback secret resolver, the three-tier network isolation, RED metrics
+ SLO recording rules, and the honest `VERIFICATION.md` are all above the bar you'd
see in most *production* repos. The gaps are concentrated in a handful of
**cross-cutting correctness issues** that would bite even in the classroom, and in
**consistency drift** between the three clouds / the k8s-vs-swarm/-vs-compose
definitions of the "same" system.

| Domain | Grade | Headline gap |
|---|---|---|
| Containers & Compose | B+ | No lockfiles → non-reproducible builds; no resource limits in compose |
| Kubernetes | B | `:latest` everywhere breaks the rollback lesson; no base NetworkPolicy; data tier unhardened |
| IaC (TF + Ansible) | A− | ECS `desired_count` fights autoscaler; DB TLS not enforced on AWS/GCP; Ansible won't actually boot the app |
| Security & Supply chain | A | Actions pinned to tags not SHAs; OSV job references non-existent lockfiles |
| Observability & SRE | B+ | No Alertmanager (alerts route nowhere); 30-day budget on 24h retention; Tempo→Prom remote-write disabled |
| CI/CD & Hygiene | B+ | `npm install` not `npm ci`; mutable `:latest` pushed from feature branches; Dependabot coverage partial |

---

## Cross-cutting themes (fix these once, benefit everywhere)

1. **No lockfiles anywhere.** There is no `package-lock.json` in any service.
   Consequences cascade: Dockerfiles use `npm install` (non-reproducible images),
   CI caches key off `package.json` not a lock, `npm audit`/Dependabot results
   drift, and the DevSecOps **OSV Scanner step points at
   `services/*/package-lock.json` that doesn't exist** (masked only by
   `continue-on-error`). **Fix:** `npm install` once per service, commit the
   lockfiles, switch every `npm install` → `npm ci` (Dockerfiles + all workflows).
   This is the single highest-leverage change in the repo.

2. **Mutable image tags.** k8s manifests, Swarm, and the compose build all resolve
   to `:latest`; CI pushes `:latest` alongside the SHA, from `feat/**` and `fix/**`
   branches too. This directly undercuts the course's own rollback exercise
   (`rollout undo` has nothing distinct to revert to) and is a real prod footgun.
   **Fix:** pin immutable tags/digests in `kustomization.yaml` + Swarm; push
   `:latest` only from `main`.

3. **"Same system," three drifting definitions.** Swarm enforces `internal: true`
   data-tier isolation; k8s base has *no* NetworkPolicy. Azure enforces DB TLS;
   AWS/GCP don't. Postgres/redis are hardened nowhere in k8s but fine in compose.
   **Fix:** treat compose/k8s/swarm/TF as one spec — pick the strongest posture and
   bring the others up to it (checklist in the roadmap below).

4. **Controllers that fight their autoscalers.** Both k8s (`Deployment.replicas` +
   HPA) and AWS (`ecs_service.desired_count` + appautoscaling) declare a static
   count *and* an autoscaler on the same dimension → scale-down thrash on every
   apply, exactly during the iftar spike the repo is built around. **Fix:**
   `lifecycle { ignore_changes = [desired_count] }` on ECS; drop `replicas:` from
   HPA-managed Deployments.

5. **Supply-chain: actions pinned to tags, not SHAs.** Every workflow uses
   `@v4/@v6` (and `checkov-action@master`). A tag is mutable; a compromised action
   release runs with `packages: write`/`id-token: write`. **Fix:** pin to full
   commit SHAs (Dependabot `github-actions` already open to bump them) and never
   pin to `@master`.

6. **Alerts with no delivery path.** Prometheus has SLO rules but no `alerting:`
   block and the stack ships no Alertmanager, so every alert dies in the UI. The
   whole symptom-based-alerting lesson has no last mile. **Fix:** add Alertmanager
   + routing.

---

## Priority roadmap (genuine gaps only)

### P0 — correctness, will bite in the classroom
- [ ] Generate & commit `package-lock.json` for orders/kitchen/dispatch; `npm ci` everywhere *(themes #1)*
- [ ] Pin immutable image tags; stop pushing `:latest` off feature branches *(#2)*
- [ ] `ignore_changes = [desired_count]` on ECS service; remove `replicas` from HPA-managed Deployments *(#4)*
- [ ] Add Alertmanager + `alerting:` block; wire severity→page/ticket routing *(#6)*
- [ ] Fix error-budget window vs retention: raise Prometheus `--storage.tsdb.retention.time` to ≥31d (currently 24h) or compute the 30-day budget from a slow recording rule
- [ ] Add `--web.enable-remote-write-receiver` (Tempo→Prom metrics 404 today) and `--enable-feature=exemplar-storage` (exemplar pivot is advertised but broken)

### P1 — security / reliability posture
- [ ] Pin GitHub Actions to SHAs; replace `checkov-action@master` *(#5)*
- [ ] k8s base NetworkPolicy default-deny + explicit allows (parity with Swarm)
- [ ] Harden data tier in k8s: `securityContext` (runAsNonRoot, drop ALL caps, seccomp) on postgres/redis; add liveness probes
- [ ] Enforce DB TLS on AWS (`rds.force_ssl=1`) and GCP (`ssl_mode=ENCRYPTED_ONLY`, `?sslmode=require`) — match Azure
- [ ] Ansible: template a `docker-compose.yml` into `/opt/daig` (systemd unit runs `docker compose up` against a file that isn't deployed) and `mkdir /etc/apt/keyrings` before writing the Docker key
- [ ] Multi-window burn-rate alerts (fast 14.4×/1h+5m → page; slow 6×/6h, 3×/24h → ticket) replacing the single 75%-consumed lagging alert
- [ ] Add resource limits to compose services; `security_opt: [no-new-privileges:true]` and `read_only` where feasible

### P2 — consistency / defense-in-depth
- [ ] HPAs for kitchen/dispatch/web (spike propagates downstream; only orders scales today)
- [ ] `topologySpreadConstraints`/anti-affinity so PDB `maxUnavailable:0` promises hold on a node drain
- [ ] `automountServiceAccountToken: false` on all pods; Pod Security Admission `enforce: restricted` label on the namespace
- [ ] AWS VPC flow logs; Azure NSGs on data/apps subnets
- [ ] cAdvisor/node-exporter for USE/saturation (OOMKilled & CPU-throttle scenarios can't be charted today)
- [ ] Ingress + TLS in front of `web` (raw L4 LoadBalancer today)
- [ ] Dependabot: add docker for kitchen/dispatch/web and terraform for gcp/azure (only orders/aws covered)

---

## Per-domain detail

### 1) Containers & Compose
- **[High] No lockfiles / `npm install` in Dockerfiles** — `services/orders/Dockerfile:9` — non-reproducible layers; `npm ci` needs a lock. Commit locks, switch to `npm ci`.
- **[Medium] No CPU/memory limits in compose** — `docker-compose.yml` — a runaway service can starve the host; the OOM/throttle chaos scenarios have no ceiling to hit. Add `deploy.resources.limits` (compose honors under `docker compose`).
- **[Medium] No `restart:` on postgres/redis** — `docker-compose.yml:29,45` — app tier has `unless-stopped`; data tier doesn't. Add for parity.
- **[Low] web depends_on app tier with no condition / no healthcheck gating** — `docker-compose.yml:78` — `web` starts as soon as containers *start*, not when healthy. Use `condition: service_healthy` (app services do define Dockerfile HEALTHCHECKs).
- **[Low] nginx proxies lack `proxy_set_header Host/X-Forwarded-*`, timeouts, `client_max_body_size`** — `services/web/nginx.conf:38-41` — backends can't see original host/scheme; no upstream timeouts.
- **[Enh] Non-root nginx, `no-new-privileges`, read-only rootfs** — harden the one internet-facing container.

### 2) Kubernetes & Orchestration
- **[Critical] `:latest` on every image** — `kustomization.yaml`, `web/orders/kitchen/dispatch.yaml` — breaks rollback + can run mixed versions. Pin digests/semver.
- **[Critical] No base NetworkPolicy** — `k8s/base/` — flat pod network; `web` can reach `postgres` directly. Add default-deny + allows (Swarm already isolates).
- **[High] Data tier unhardened** — `postgres.yaml:22`, `redis.yaml:18` — no securityContext, no liveness probe; highest-value pods, least protected.
- **[High] Redis Deployment with no PVC** — `redis.yaml` — state lost on reschedule; StatefulSet if it holds more than pure cache.
- **[High] HPA vs static `replicas`, and orders-only HPA** — `hpa.yaml:13` vs `orders.yaml:9` — scale thrash; kitchen/dispatch/web don't scale with the spike.
- **[Medium] `web` unhardened, raw LoadBalancer, no PDB, shared liveness/readiness** — `web.yaml` — front with Ingress+TLS, add PDB, split probes.
- **[Medium] `default` SA token auto-mounted on all pods** — set `automountServiceAccountToken: false`.
- **[Low] No PSA label on namespace; `commonLabels` deprecated; no preStop/grace** — polish for enforceable hardening & clean rollouts.

### 3) IaC (Terraform + Ansible)
- **[High] ECS `desired_count` fights autoscaler** — `infra/aws/compute.tf:159` + `autoscaling.tf:8` — `ignore_changes = [desired_count]`.
- **[Medium] App won't boot via Ansible** — `roles/daig_app/templates/daig.service.j2:12` — unit runs `docker compose up` but no compose file is deployed. Template one in.
- **[Medium] apt keyring dir missing** — `roles/docker/tasks/main.yml:3` — `mkdir -p /etc/apt/keyrings` first.
- **[Medium] DB TLS not enforced on AWS/GCP** — `infra/aws/data.tf:25`, `infra/gcp/data.tf:73` — Azure does it right; match it.
- **[Medium] No VPC flow logs (AWS) / no NSGs (Azure)** — add the control points.
- **[Low] `host_key_checking=False`; no package pinning; hardcoded `arch=amd64`; dead `node_major_version`/`docker_compose_version` vars; cross-cloud tag drift** — reproducibility & arm64 support.
- **[Enh] KMS CMKs, ALB access logs + TLS, RDS enhanced monitoring, per-service GCP SAs, Azure diagnostic settings, consistent log retention.**
- *(Teaching, leave: commented-out remote state backends, ALB HTTP-only, `recovery_window_in_days=0`, single NAT, plaintext dev DB password.)*

### 4) Security & Supply Chain
- **[High] Actions pinned to tags, not SHAs; `checkov-action@master`** — all workflows — pin to commit SHAs.
- **[Medium] OSV Scanner targets non-existent lockfiles** — `devsecops.yml` — real once locks land (theme #1); today it silently no-ops.
- **[Low] `scan-all.sh` mounts docker.sock into Trivy/Syft** — `security/scan-all.sh:60` — acceptable locally, but it's the pattern the course warns about; note it.
- **[Enh] Kyverno policies exist but aren't applied in-cluster** — `security/kyverno/policies.yaml` — the enforcement story is conftest-in-CI only; consider admission enforcement to close the loop.
- **Strengths (keep):** keyless cosign signing + SBOM attestation, provenance `mode=max`, blocking Trivy image gate with `ignore-unfixed`, Vault AppRole with per-service least-privilege + explicit denies, no-silent-fallback secret resolver (`secrets.js`), gitleaks over full history.
- *(Teaching, leave: `insecure.js`, `tls_disable=true`, `CHANGE_ME_DEV_ONLY` bait, file storage backend.)*

### 5) Observability & SRE
- **[Critical] No Alertmanager** — `prometheus.yml`, `docker-compose.obs.yml` — alerts route nowhere. Add it + routing.
- **[Critical] 30-day budget on 24h retention** — `rules/slo.yml:20` vs `docker-compose.obs.yml:26` — budget gauge silently reports 24h scaled as 30d. Raise retention or use a slow recording rule.
- **[High] Tempo→Prometheus remote-write disabled** — `tempo.yaml:35` — add `--web.enable-remote-write-receiver`; service-graph metrics dropped today.
- **[High] Exemplar metrics↔traces pivot broken end-to-end** — `metrics.js`, datasource — needs `--enable-feature=exemplar-storage`, OpenMetrics content-type, and exemplars attached in the middleware.
- **[High] No multi-window burn-rate alerts** — single 75%-consumed lagging alert; `DaigOrdersFailing` tolerates 10× burn before paging.
- **[Medium] No USE/host metrics (no cAdvisor/node-exporter); spanmetrics collected but unused; load-shed 503s counted as SLO errors; no trace sampling; DB metric has no error dimension.**
- **[Low] Loki 72h / Tempo 48h / Prom 24h retention mismatch; OTLP logs pipeline dead-ends; env label overwritten.**
- **[Enh] Alert on the telemetry plane itself; latency error-budget; burn-rate + inflight dashboard panels.**
- *(Teaching, leave: the six `chaos/day*.sh` exercises are well-formed with steady-state + revert; Grafana admin dummy creds are Day-6 scanner bait. Watch-items: Day-1 iptables fallback message misleads; confirm Day-4 `CHAOS_*` envs pass through compose.)*

### 6) CI/CD & Repo Hygiene
- **[High] `npm install` not `npm ci`; cache keyed on `package.json`** — `ci.yml`, `security.yml`, `devsecops.yml` — reproducibility (theme #1).
- **[High] Mutable `:latest` pushed from `feat/**`,`fix/**`** — `ci.yml` build job — restrict to `main`; pin digests for deploys.
- **[Medium] Dependabot partial** — `dependabot.yml` — docker only for orders; terraform only for aws. Add the rest.
- **[Medium] Security gate only blocks on `secrets`+`build`** — `devsecops.yml` gate — SAST/CodeQL/IaC failures fail their own jobs, but the explicit gate should reflect them for a clear required-check story.
- **[Low] Dummy-value allowlist differs across pre-commit hook, `ci.yml`, and `devsecops.yml`** — three lists drift (e.g. `security/`, `docker-compose.security.yml` present in some, not others). Centralize one list.
- **Strengths (keep):** iftar-window deploy guard, OIDC (`id-token: write`, no long-lived cloud keys), `cancel-in-progress:false` on CD, integration job that brings the whole stack up + tears down, `set -euo pipefail` discipline in scripts, thorough pre-commit hook.
- *(Teaching, leave: `cd.yml` rollout steps are intentional TODO stubs mapped to each platform's real mechanism.)*

---

## What to explicitly NOT change (deliberate curriculum)
`services/orders/src/insecure.js`, `k8s/base/secret.yaml` plaintext, `vault` `tls_disable=true` + file storage, commented-out TF remote-state backends, ALB HTTP-only, single NAT, `recovery_window_in_days=0`, `CHANGE_ME_DEV_ONLY` values, and the `chaos/day*.sh` scenarios are all annotated teaching artifacts. Each is correctly flagged in-file and/or in `VERIFICATION.md`. Leave them; they are the lesson.

---

*Two of six domain passes (containers, security, CI/CD) were completed by direct
file review after the parallel agents hit a session usage limit; K8s, IaC, and
observability came from dedicated specialist passes. Every finding cites a real
file. Nothing here has been executed — consistent with `VERIFICATION.md`.*
