<div align="center">

# DevOps Intern Rotation 2026

**A complete, teachable DevOps curriculum — kickoff deck, day-by-day plan, and a deliberately breakable platform to learn on.**

Design docs, a 38-slide kickoff deck, and **[daig](daig/)** — a three-tier
platform that is instrumented end-to-end and broken on purpose, so there is
always something true to find.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](daig/LICENSE)
[![Node](https://img.shields.io/badge/node-22-green.svg)](daig/.nvmrc)
[![Status](https://img.shields.io/badge/status-unverified-orange.svg)](daig/VERIFICATION.md)
[![Docs](https://img.shields.io/badge/docs-13%20guides-informational.svg)](#the-curriculum)

</div>

---

> **Honesty first.** Every file here is syntax-checked. **Nothing has been run
> end-to-end.** Those are different claims, and this repo never blurs them — see
> [`daig/VERIFICATION.md`](daig/VERIFICATION.md). That distinction is the first
> thing the rotation teaches.

---

## What this is

A ready-to-run training program for onboarding DevOps interns over a six-day
hands-on rotation, plus a two-hour kickoff. It ships three things:

- **The plan** — audit of last year's deck, a redesigned kickoff, a charter with
  57 tasks across 8 milestones, a skills matrix, cheat sheet, and instructor
  solutions.
- **The deck** — `devops-kickoff-2026.pptx` (38 slides, full speaker notes) and a
  PDF alongside.
- **The platform** — [`daig/`](daig/), a food-delivery app with real distributed
  tracing, real secret management, real IaC, and defects labelled in place.

> **daig** *(n.)* — the pot you cook in when you're feeding everybody at once. Its
> defining failure is the forty minutes before iftar, when a whole country orders
> dinner simultaneously against a deadline set by the sun.

---

## The learning loop

Each day peels back one layer of the stack:

```
1. Watch it work   →   2. Break it   →   3. Diagnose   →   4. Fix it   →   5. Gate it
   make up · obs        chaos scripts     logs·metrics      right layer     test·rule·policy
        ↑___________________________ next day, next layer ___________________________|
```

---

## The curriculum

Read **03 (CHARTER)** first if you're planning. Read **08 (DAIG)** first if you're
running the code.

| # | Doc | Audience | What it is |
|---|-----|----------|------------|
| 0 | [`00-START-HERE.md`](00-START-HERE.md) | you | The map — index, run/push steps, open decisions. |
| 1 | [`01-AUDIT-devops-intern-deck-2025.md`](01-AUDIT-devops-intern-deck-2025.md) | you | Slide-by-slide audit of last year's deck. |
| 2 | [`02-DESIGN-devops-intern-kickoff-2026.md`](02-DESIGN-devops-intern-kickoff-2026.md) | you | Kickoff design, run sheet timed to the minute. |
| 3 | [`03-CHARTER-objective-milestones-tasks.md`](03-CHARTER-objective-milestones-tasks.md) | **you first** | Objective, 24 checkpoints, 8 milestones, 16 targets, 57 tasks. |
| 4 | [`04-COVERAGE-skills-matrix.md`](04-COVERAGE-skills-matrix.md) | you | The scope decision — 20 skills, 6 days, honest depth for each. |
| 5 | [`05-CHEATSHEET-handout.md`](05-CHEATSHEET-handout.md) | **interns** | Commands and the diagnostic ladder. No answers — safe to print. |
| 6 | [`06-SOLUTIONS-instructor-only.md`](06-SOLUTIONS-instructor-only.md) | **you only** | Worked steps for every task, chaos variant, and checkpoint. |
| 7 | [`07-DEVSECOPS-guide.md`](07-DEVSECOPS-guide.md) | you | Seven gates, six vulnerabilities, supply chain, secrets. |
| 8 | [`08-DAIG-README.md`](08-DAIG-README.md) | both | The platform README, with architecture and flow diagrams. |
| 9 | [`09-ARCHITECTURE.md`](09-ARCHITECTURE.md) | you | Eighteen design decisions and the alternatives rejected. |
| 10 | [`10-REQUIREMENTS.md`](10-REQUIREMENTS.md) | you | 28 functional and 45 non-functional requirements, traceable. |
| 11 | [`11-DEPLOYMENT.md`](11-DEPLOYMENT.md) | both | Per-environment procedures and rollback. |
| 12 | [`12-COST-estimate.md`](12-COST-estimate.md) + [`.py`](12-cost-model.py) | you | What it costs on each cloud. Computed, not asserted. |

---

## The platform stack

Everything in [`daig/`](daig/) is real and wired together:

| Layer | Tooling |
|-------|---------|
| **App** | Node 22 · three services (customer, restaurant, rider) · one database · one payment integration |
| **Containers** | Docker Compose (base + observability, security, sonar, vault overlays) |
| **Orchestration** | Kubernetes manifests ([`k8s/`](daig/k8s)) · Docker Swarm ([`swarm/`](daig/swarm)) |
| **Observability** | Metrics, logs, traces, profiles ([`observability/`](daig/observability)) |
| **IaC** | Terraform ([`infra/`](daig/infra), incl. GCP) · Ansible ([`ansible/`](daig/ansible)) |
| **Security** | Static analysis, secret scanning, SonarQube ([`security/`](daig/security)) |
| **Secrets** | Vault / OpenBao init, unseal, policies, AppRole ([`vault/`](daig/vault)) |
| **Resilience** | Chaos experiments ([`chaos/`](daig/chaos)) · load tests ([`load/`](daig/load)) |

---

## Quick start

```bash
cd daig
cp .env.example .env
make hooks        # install the pre-commit hook
make check        # static checks, no Docker needed
make up && make seed && make smoke
make obs          # observability stack
make vault-up     # OpenBao: initialise, unseal, provision
make vault-app    # run daig with credentials from the vault
make help         # everything else
```

Full details in [`daig/README.md`](daig/README.md).

---

## Repository layout

```
.
├── 00-START-HERE.md … 12-COST-estimate.md   # the curriculum (13 guides)
├── 12-cost-model.py                          # cloud cost model
├── devops-kickoff-2026.pptx / .pdf           # the deck (38 slides)
└── daig/                                     # the demo platform
    ├── services/            # customer · restaurant · rider
    ├── observability/       # metrics · logs · traces · profiles
    ├── infra/  ansible/     # Terraform (incl. GCP) + config mgmt
    ├── k8s/    swarm/        # orchestration
    ├── security/  vault/    # scanning + secret management
    ├── chaos/  load/        # resilience + load testing
    └── docs/                # CHARTER · CHEATSHEET · SOLUTIONS · COST
```

---

## Status & open decisions

Do a half-day dry run of `daig/` before Day 1 —
[`VERIFICATION.md`](daig/VERIFICATION.md) names what's verified, what isn't, and
the likeliest first failure. Three decisions to settle before the kickoff:

1. **Six days or five** — `04-COVERAGE` lays out three options (Option A is six days).
2. **Which cloud is hands-on** — one done properly beats three clicked through.
3. **Cloud sandbox with a spend cap** — set the budget alert before the first
   `terraform apply`, not after.

---

## License

MIT — see [`daig/LICENSE`](daig/LICENSE).
