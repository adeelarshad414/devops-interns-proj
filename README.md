# DevOps Intern Rotation 2026

Everything for the 2-hour kickoff and the six-day hands-on rotation — the design
docs, the presentation deck, and **daig**, the demo platform interns build and
break.

> New here? Read [`00-START-HERE.md`](00-START-HERE.md) first. It's the map for
> everything below.

---

## What's in this repo

### Planning & design docs

| # | File | Audience | What it is |
|---|------|----------|------------|
| 0 | [`00-START-HERE.md`](00-START-HERE.md) | you | The entry point — index, run/push instructions, open decisions. |
| 1 | [`01-AUDIT-devops-intern-deck-2025.md`](01-AUDIT-devops-intern-deck-2025.md) | you | Slide-by-slide audit of last year's deck. |
| 2 | [`02-DESIGN-devops-intern-kickoff-2026.md`](02-DESIGN-devops-intern-kickoff-2026.md) | you | Kickoff design, run sheet timed to the minute. |
| 3 | [`03-CHARTER-objective-milestones-tasks.md`](03-CHARTER-objective-milestones-tasks.md) | **you first** | Objective, 24 checkpoint questions, 8 milestones, 16 targets, 57 tasks. |
| 4 | [`04-COVERAGE-skills-matrix.md`](04-COVERAGE-skills-matrix.md) | you | The scope decision — 20 skills, 6 days, an honest depth level for each. |
| 5 | [`05-CHEATSHEET-handout.md`](05-CHEATSHEET-handout.md) | **interns, Day 1** | Commands and the diagnostic ladder. No answers — safe to print. |
| 6 | [`06-SOLUTIONS-instructor-only.md`](06-SOLUTIONS-instructor-only.md) | **you only** | Step-by-step for every task, chaos variant and checkpoint question. |
| 7 | [`07-DEVSECOPS-guide.md`](07-DEVSECOPS-guide.md) | you | Seven gates, six vulnerabilities, supply chain, secrets. |
| 8 | [`08-DAIG-README.md`](08-DAIG-README.md) | both | The platform README, with architecture and flow diagrams. |
| 9 | [`09-ARCHITECTURE.md`](09-ARCHITECTURE.md) | you | Eighteen design decisions and the alternatives rejected. |
| 10 | [`10-REQUIREMENTS.md`](10-REQUIREMENTS.md) | you | 28 functional and 45 non-functional requirements, with traceability. |
| 11 | [`11-DEPLOYMENT.md`](11-DEPLOYMENT.md) | both | Per-environment procedures and rollback. |
| 12 | [`12-COST-estimate.md`](12-COST-estimate.md) + [`12-cost-model.py`](12-cost-model.py) | you | What it costs on each cloud. Computed, not asserted. |

### The deck

- `devops-kickoff-2026.pptx` — 38 slides, speaker notes on all of them
- `devops-kickoff-2026.pdf` — PDF alongside

### The demo platform

- [`daig/`](daig/) — the full demo repository: Docker Compose stack, Ansible,
  Kubernetes manifests, observability, security scanning, chaos experiments, and
  a Vault/OpenBao setup. See [`daig/README.md`](daig/README.md).

**Start with doc 3 (CHARTER) if you're planning. Start with doc 8 (or
`daig/README.md`) if you're running the code.**

---

## Quick start — running daig

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

---

## Status

Every file is syntax-checked; none has been executed end-to-end. See
[`daig/VERIFICATION.md`](daig/VERIFICATION.md) for what is verified vs. what is
not, and the likeliest first failure. Do a half-day dry run of the repo before
Day 1.

---

## Open decisions

Carried over from [`00-START-HERE.md`](00-START-HERE.md) — resolve these before the kickoff:

1. **Six days or five** — `04-COVERAGE` lays out three options (Option A is six days).
2. **Which cloud is hands-on** — one done properly beats three clicked through.
3. **Cloud sandbox with a spend cap** — set the budget alert before the first
   `terraform apply`, not after.
