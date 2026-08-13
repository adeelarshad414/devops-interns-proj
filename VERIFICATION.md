# Verification status

Written 3 August 2026. This file exists because "it should work" and "I ran it"
are different claims, and a teaching repository that blurs them teaches exactly
the wrong lesson.

> **Update 13 August 2026.** The core stack is no longer just syntax-checked — it
> **runs, and CI proves it on every push.** A boot-blocking dependency-resolution
> bug was fixed (`_shared` now owns its deps), the OpenTelemetry stack was bumped
> (`npm audit` → 0), and an nginx `log_format` misplacement that crashed `web` was
> corrected. The `Integration` job stands the whole stack up and places a real
> order. Rows below are updated accordingly; the genuinely un-run parts (cloud
> `apply`, OpenBao e2e, a real cluster) remain honestly marked.

## Legend

- **VERIFIED (real)** — executed, output inspected
- **VERIFIED (static)** — parsed or syntax-checked by a tool, not executed
- **UNVERIFIED** — written and reviewed by eye only

## Current state

| Area | Status | How |
|---|---|---|
| Node source — 4 services, shared libs, load generator | VERIFIED (static) | `node --check` on every `.js`, clean |
| npm lockfiles — orders/kitchen/dispatch + `_shared` | VERIFIED (static) | committed; `npm audit` = **0 vulnerabilities** across all four (heavy deps moved into `_shared`, OpenTelemetry bumped to current) |
| Shared-lib module resolution | VERIFIED (real) | `_shared/{telemetry,metrics,db,logger,secrets,guard}` all `require()`-load with `_shared/node_modules` present — fixes the `MODULE_NOT_FOUND` boot failure |
| Shell — chaos, scripts, pre-commit hook | VERIFIED (static) | `bash -n`, clean |
| YAML — compose ×4, workflows ×5, k8s, observability, ansible, swarm | VERIFIED (static) | PyYAML `safe_load_all` incl. `.github/`, every document loads |
| GitHub Actions — action pinning | VERIFIED (static) | every `uses:` resolved to a commit SHA via the GitHub API |
| JSON — Grafana dashboard | VERIFIED (static) | `json.load`, parses |
| Terraform — AWS, GCP, Azure | **UNVERIFIED** | no `terraform` binary available; brace/paren balance checked only |
| SQL schema and seed | **UNVERIFIED** | no PostgreSQL available |
| Dockerfiles ×4 | **VERIFIED (real)** | built by CI on every push — `Build image` jobs (orders/kitchen/dispatch/web) all green |
| `docker compose config` — base + observability | VERIFIED (static) | both overlays render with `docker compose config` (merge anchors, limits, alertmanager resolve) |
| `docker compose up` end to end | **VERIFIED (real)** | CI `Integration` job (a required merge gate): full stack healthy → seeded → smoke-tested → a real order placed orders→kitchen→dispatch |
| Kubernetes manifests | VERIFIED (static) | `kubectl kustomize k8s/base` builds cleanly — 28 objects, images pinned, no `:latest` |
| Swarm stack | **UNVERIFIED** | no Docker daemon |
| Ansible playbooks | **UNVERIFIED** | no `ansible-lint`, no target host |
| Grafana dashboard panels | **UNVERIFIED** | JSON parses; never rendered |
| GitHub Actions workflows | **UNVERIFIED as runs** | YAML parses; never executed on a runner |
| SonarQube scan | **UNVERIFIED** | never run against the code |
| Semgrep rules | **UNVERIFIED** | YAML parses; patterns never matched against real code. Custom rule syntax is the likeliest thing here to need adjusting. |
| OPA/Rego policies ×3 | **UNVERIFIED** | never run through `conftest` or `opa eval`. Rego v1 syntax, unexercised. |
| Kyverno policies | **UNVERIFIED** | YAML parses; never applied to a cluster |
| Vulnerable endpoints | **UNVERIFIED** | `node --check` clean; never executed or probed |
| `chaos/day6-security.sh verify` | **UNVERIFIED** | `bash -n` clean; detection logic never exercised |
| cosign / syft / OpenBao scripts | **UNVERIFIED** | `bash -n` clean; no binaries available |
| Falco rules | **UNVERIFIED** | YAML parses; never loaded by Falco |
| OpenBao server config (`config.hcl`) | **UNVERIFIED** | no `bao` binary; HCL never parsed by OpenBao |
| OpenBao policies ×4 | **UNVERIFIED** | HCL never loaded; capability syntax unexercised |
| `vault/bootstrap.sh` | **UNVERIFIED** | `bash -n` clean; init/unseal/AppRole flow never executed |
| `vault/demo.sh` | **UNVERIFIED** | `bash -n` clean |
| `services/_shared/secrets.js` | **VERIFIED (static)** | `node --check` clean; AppRole login and KV read never exercised against a live OpenBao |
| Service bootstrap split (index.js / server.js) | **VERIFIED (static)** | `node --check` clean on all six files |
| OpenBao Agent config | **UNVERIFIED** | HCL and template never rendered |
| `scripts/init-repo.sh` | **UNVERIFIED** | `bash -n` clean; never run against a real repo |
| Markdown cross-links | **VERIFIED (real)** | every relative link in every `.md` resolved to an existing file — 0 broken |
| Mermaid diagrams | **VERIFIED (static)** | fences balanced; never rendered by GitHub |
| `scripts/cost-model.py` | **VERIFIED (real)** | executed; output inspected; exposed and fixed a real cost defect in `infra/gcp` |
| Cost figures in `docs/COST.md` | **VERIFIED (computed)** | derived from the model, not typed. Rates marked `[E]` are unverified secondary sources; **never compared to an actual invoice** |

## What this means for you

**Before Monday, someone must actually run this.** Budget half a day. The most
likely failures, in rough order of probability:

1. **OpenTelemetry JS package versions.** This ecosystem churns faster than
   anything else in the stack — package names and export shapes have changed
   repeatedly. The pins here are a best guess and are the single most likely
   thing to break the install. (There is now a committed `package-lock.json`,
   so `npm ci` will fail fast and loudly if the lock and manifest ever drift.)
2. **`npm ci` inside the Docker build** — the lockfiles were generated but the
   images were never built; a transitive pin may still surprise you.
3. **Terraform provider arguments.** Provider majors rename and deprecate
   arguments regularly. Expect at least one fix per cloud.
4. **Postgres init ordering** against the compose healthcheck timing.
5. **SonarQube's mmap limit** — needs `vm.max_map_count=524288` on the host or
   Elasticsearch refuses to start.
6. **Semgrep custom rule syntax.** Pattern metavariables and `metavariable-pattern`
   are fiddly. Expect at least one of the six rules in
   `security/semgrep/daig.yml` to need adjusting. Run
   `semgrep --validate --config security/semgrep/daig.yml` first — it is fast
   and catches most of it.
7. **Rego v1 syntax.** The `import rego.v1` form with `contains` rules is
   current but strict. `conftest verify` or `opa check` will tell you quickly.
8. **The OpenBao AppRole flow.** `bootstrap.sh` is the longest unexercised script
   in the repository and touches init, unseal, policy write, AppRole create and a
   verification login. Expect at least one CLI flag to differ. Run it early —
   `make vault-up` — because `secrets.js` depends on the output format.
9. **Compose `--env-file` ordering** in `make vault-app`. Later files override
   earlier ones; if a service reports `credential_source: environment` when it
   should say `openbao`, that precedence is the first thing to check.

None of these are design problems. All of them are the ordinary cost of never
having executed the code, and I would rather say so than let you discover it in
front of twenty interns.

## Priority order if you only have two hours

1. `make up` → `make seed` → `make smoke`
2. `make broken` then `docker run tkxel/daig-orders:broken` — **the kickoff
   exercise depends on this.** Confirm the log names `DATABASE_URL` and the
   exit code is 78.
3. `make obs` — confirm one trace crosses all three services in Tempo

If you are also running the DevSecOps day, add a fourth:

4. `./chaos/day6-security.sh break` then `./security/scan-all.sh sast` — confirm
   Semgrep actually reports the five findable vulnerabilities. If it reports
   zero, the custom rules need fixing and the exercise collapses.

Those three cover the kickoff and Day 4, which are the two sessions that fail
hardest if the demo does not work.

## Update this file as you verify

Change rows to **VERIFIED (real)** with the date and what you ran. Do not delete
rows. An honest record of what has actually been executed is worth more than a
clean-looking table — and it is the habit this whole rotation is trying to
teach.
