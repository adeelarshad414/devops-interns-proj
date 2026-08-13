# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning is [semantic](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed — hardening from the expert audit (`planning/AUDIT-2026-expert-review.md`)

- **Reproducible builds:** committed `package-lock.json` for orders/kitchen/
  dispatch; Dockerfiles and every workflow now use `npm ci`, not `npm install`
- **Immutable images:** k8s/Swarm images pinned (`1.0.0`, was `:latest`); CI
  publishes `:latest` only from the default branch via `docker/metadata-action`
- **Kubernetes:** base default-deny `NetworkPolicy` + tier allows; data tier
  hardened (securityContext, liveness); `redis` → StatefulSet with a PVC; static
  `replicas` removed from HPA-managed Deployments; HPAs added for kitchen/
  dispatch/web; `topologySpreadConstraints` + `automountServiceAccountToken:false`
  on all pods; web PDB + startup probe; namespace Pod Security Admission
  (baseline enforce, restricted warn/audit); `hpa.yaml` + `networkpolicy.yaml`
  wired into kustomize; deprecated `commonLabels` → `labels`
- **IaC:** ECS `ignore_changes = [desired_count]`; DB TLS enforced (AWS
  `sslmode=require` + `rds.force_ssl`, GCP `ENCRYPTED_ONLY`); AWS VPC flow logs;
  Ansible now creates `/etc/apt/keyrings`, is architecture-aware, and deploys a
  compose file so the systemd unit boots
- **Observability:** Alertmanager added (service + config + `alerting:` block);
  Prometheus retention 24h → 31d; remote-write receiver + exemplar storage
  enabled; multi-window burn-rate SLO alerts (fast/slow/ticket)
- **Compose:** per-service resource limits, `no-new-privileges`, restart on the
  data tier, health-gated `web` startup

### Fixed

- **The application could not start (shared-lib dependency resolution).**
  `services/_shared/{telemetry,metrics,db,logger}.js` require `@opentelemetry/*`,
  `pg`, `prom-client` and `pino`, but those were declared in each *service's*
  `package.json` — so Node, resolving from `services/_shared/`, never found
  `services/<svc>/node_modules` and threw `Cannot find module '@opentelemetry/sdk-node'`
  at boot (the real reason the integration job failed). Fixed by making
  `_shared` a proper package that owns those deps, trimming services to their
  direct deps (`express`, `undici`), and updating the Dockerfiles to install and
  ship `services/_shared/node_modules`. Added a root `.dockerignore` (Docker only
  honours the context-root one).
- **Dependency vulnerabilities cleared.** Bumping the OpenTelemetry stack to
  current versions in `_shared` (the modern API in the code was already
  compatible) takes `npm audit` to **0 vulnerabilities** across all services and
  `_shared` (was 43, incl. 4 high / 9 high across the repo per Dependabot).
- **`node --test test/` → `node --test`.** The path form makes Node 22+ resolve
  `test/` as a module (`MODULE_NOT_FOUND`); auto-discovery fixes the `orders`
  unit-test CI job (verified: 3 pass).
- **Repo layout:** promoted the project to the repository root so GitHub actually
  runs the workflows (they were dormant under `daig/.github/`); kickoff deck and
  planning docs archived under `planning/`.
- **Supply chain:** every GitHub Action pinned to a commit SHA (was mutable
  tags; `checkov-action` was `@master`); `trivy-action` corrected to a valid
  tag (`v0.24.0`); `osv-scanner-action` pinned to `v1.9.2`
- **CI YAML gate** now parses hidden dirs (`os.walk`, not `glob('**')`) so the
  workflow files are checked too — this caught an invalid plain scalar in
  `cd.yml` (`run: echo "TODO: …"`), now a block scalar
- **Dummy-value gate** allowlist corrected and unified across `ci.yml`,
  `devsecops.yml` and the pre-commit hook; the previous narrow list would have
  failed the build on files that legitimately carry the registered placeholder

### To verify

The **core stack now runs end-to-end in CI** (the `Integration` job: all six
containers healthy, seeded, smoke-tested, a real order placed) and all four
images build. Still genuinely un-run and honestly tracked in `VERIFICATION.md`:
a live `terraform apply` on any cloud, the OpenBao end-to-end credential flow,
and deployment to a real Kubernetes cluster.

## [0.1.0] - 2026-08-03

First assembly. Built as the demo substrate for the 2026 intern rotation.

### Added — application

- Three-tier architecture: nginx presentation tier, three Node services, Postgres
  and Redis data tier
- Cross-service distributed tracing — one browser request produces one trace
  spanning all three application services
- `orders` → `kitchen` → `dispatch` call chain with an append-only
  `order_events` audit table

### Added — credentials

- OpenBao (Linux Foundation Vault fork) with file storage and a real seal, not
  dev mode
- Shamir 5-of-3 unseal, AppRole per service, four least-privilege policies
- `services/_shared/secrets.js` — resolves from OpenBao, falls back to
  environment only outside production, exits 78 rather than guessing
- Dynamic PostgreSQL credentials with a TTL, behind `BAO_DYNAMIC_DB=true`
- OpenBao Agent sidecar configured as the documented alternative to in-app
  integration
- Audit device enabled before any secret is written

### Added — observability

- OpenTelemetry Collector, Prometheus, Loki, Promtail, Tempo, Pyroscope, Grafana
- SLO recording rules and four alerts built on a 99.9% / 43-minutes-a-month
  error budget
- Provisioned pivot chain: metrics → trace → logs → flame graph in four clicks

### Added — DevSecOps

- Seven-gate pipeline ordered by cost of feedback: secrets, SAST, SCA, IaC,
  image, DAST, runtime
- Six deliberate CWE-tagged vulnerabilities, gated behind `INSECURE_MODE`
- Custom Semgrep rules, three OPA/Rego policy files, Kyverno admission policies
- SBOM generation, SLSA provenance, keyless cosign signing and verification
- OWASP ZAP baseline with a triaged rule file, Falco runtime rules

### Added — infrastructure

- Terraform for AWS (ECS Fargate, RDS, ALB), GCP (Cloud Run, Cloud SQL) and
  Azure (Container Apps, Flexible Server) — deliberately parallel
- Ansible: four roles, idempotent, discovered rather than explained
- Kubernetes manifests and a Docker Swarm stack, with a translation table
  between them
- SonarQube overlay with a quality gate on new code

### Added — teaching

- Six chaos exercises, one per day, with three planted variants on Day 1
- Zero-dependency iftar spike load generator
- Twelve documentation files: six day guides, instructor notes, Git, Docker
  networks and volumes, Swarm, SonarQube, DevSecOps, coverage matrix

### Known limitations

- Nothing executed. `VERIFICATION.md` is the authority.
- OpenTelemetry JS package versions are the likeliest thing to break first
- Terraform never `init`ed, `validate`d or `plan`ned
- Rego v1 syntax and custom Semgrep rules unexercised
- Falco requires kernel access; may not run on Docker Desktop for macOS
