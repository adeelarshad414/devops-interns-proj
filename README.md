# DevOps Intern Rotation 2026

Everything for the 2-hour kickoff and the six-day hands-on rotation — the design
docs, the presentation deck, and **daig**, the demo platform interns build and
break.

> New here? Read [`00-START-HERE.md`](00-START-HERE.md) first. It's the map for
> everything below.

---

## What's in this repo

### Planning & design docs

| # | File | What it is |
|---|------|------------|
| 0 | [`00-START-HERE.md`](00-START-HERE.md) | The entry point — index, run/push instructions, open decisions. |
| 1 | [`01-AUDIT-devops-intern-deck-2025.md`](01-AUDIT-devops-intern-deck-2025.md) | Slide-by-slide audit of last year's 65-slide deck. |
| 2 | [`02-DESIGN-devops-intern-kickoff-2026.md`](02-DESIGN-devops-intern-kickoff-2026.md) | Design for the kickoff and rotation, with a minute-by-minute run sheet. |
| 3 | [`03-COVERAGE-skills-matrix.md`](03-COVERAGE-skills-matrix.md) | The scope decision — 20 skills, 6 days, an honest depth level for each. |
| 4 | [`04-DEVSECOPS-guide.md`](04-DEVSECOPS-guide.md) | Seven gates, six vulnerabilities, supply chain, secrets. |
| 5 | [`05-DAIG-README.md`](05-DAIG-README.md) | The demo platform's README, with architecture and flow diagrams. |
| 6 | [`06-ARCHITECTURE.md`](06-ARCHITECTURE.md) | Eighteen design decisions and the alternatives rejected. |
| 7 | [`07-REQUIREMENTS.md`](07-REQUIREMENTS.md) | 28 functional and 45 non-functional requirements, with traceability. |
| 8 | [`08-DEPLOYMENT.md`](08-DEPLOYMENT.md) | Environment-by-environment procedures and rollback. |

### The deck

- `devops-kickoff-2026.pptx` — 38 slides, speaker notes on all of them
- `devops-kickoff-2026.pdf` — PDF alongside

### The demo platform

- [`daig/`](daig/) — the full demo repository (185 files): Docker Compose stack,
  Ansible, Kubernetes manifests, observability, security scanning, chaos
  experiments, and a Vault/OpenBao setup. See [`daig/README.md`](daig/README.md).

**Start with doc 3 if you're planning. Start with doc 5 (or `daig/README.md`) if
you're running the code.**

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

1. **Six days or five** — `03-COVERAGE` lays out three options.
2. **Which cloud is hands-on** — one done properly beats three clicked through.
3. **Cloud sandbox with a spend cap** — set the budget alert before the first
   `terraform apply`, not after.
