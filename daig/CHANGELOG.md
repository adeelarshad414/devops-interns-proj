# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning is [semantic](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### To verify

Nothing in this release has been executed. See `VERIFICATION.md` for the exact
split between syntax-checked and verified. Before the first cohort, someone must
run the stack end to end.

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
