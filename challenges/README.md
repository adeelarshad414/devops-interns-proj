# Challenges — the break/fix arena 🥊

The rest of this repo teaches by *reading*. This turns it into something you
**fight**: a challenge injects a broken state into the running system, you diagnose
and fix it, and the [auto-grader](../grader/) probes the live system and tells you —
per check, with a hint on every miss — whether you actually fixed it.

```
  break it            you fix it            grade it
 ┌──────────┐        ┌──────────┐        ┌──────────────────────────┐
 │ chaos/*  │  ───▶  │  the     │  ───▶  │ grader probes Prometheus │
 │ injects  │        │  learner │        │ /HTTP/shell/files → score│
 └──────────┘        └──────────┘        └──────────────────────────┘
```

That grading engine is the backbone the whole platform can plug into — an
interactive lab, a CI gate, a CTF scoreboard all call the same `grader.py`.

## Run it

```bash
make grade-selftest            # grade the engine self-test (offline, no stack needed)
make challenges                # list available challenges

# A real break/fix loop (needs the stack up: `make obs`):
./chaos/day4-latency.sh break  # inject the fault
make grade C=fix-dispatch-latency
# ...diagnose from the trace, apply your fix...
make grade C=fix-dispatch-latency   # re-grade until SOLVED
```

Exit code is 0 only when a challenge fully passes, so the same engine drives a
lab, a CI gate, or a scoreboard.

## Authoring a challenge

A challenge is a YAML file: metadata plus a list of **checks** that assert the
desired (fixed) state. A challenge is solved when every check passes.

```yaml
id: fix-dispatch-latency
title: "Restore dispatch latency"
scenario: docs/DAY4.md          # the runbook
points: 30
intro: |
  What's broken and how to grade it.
checks:
  - name: dispatch p95 under SLO
    type: prometheus
    query: 'histogram_quantile(0.95, ...)/1000'
    assert: { op: "<", value: 1.0 }
    hint: "Open the assign trace; count the per-rider queries."
```

### Check types

| type | asserts | key fields |
|------|---------|-----------|
| `file` | a repo/config file's state | `path`, `exists` / `contains` (+`regex`) / `absent` |
| `shell` | a command's outcome | `cmd`, `expect_exit` (0), `expect_stdout_contains` |
| `http` | an endpoint's response | `url`, `expect_status` (200), `expect_contains` |
| `prometheus` | a metric value | `query`, `assert: {op, value}` (op ∈ `< <= > >= == !=`) |

Endpoints default to the compose stack (`localhost:8080`, `PROM_URL=localhost:9090`);
override with env vars for a k8s or remote target.

> **Trust boundary:** `shell` checks run commands from the challenge YAML. Challenge
> files are trusted, repo-authored content — never point the grader at a challenge
> file from an untrusted source. The engine itself is stdlib-only.

## What's here

- `_selftest.yml` — exercises every check type against known-true repo state so CI
  can verify the engine offline on every PR (see `grader/test_grader.py`).
- `fix-dispatch-latency.yml`, `restore-availability.yml` — real live break/fix
  challenges mapped to the chaos scenarios.

## Where to take it next

- Progress + points persisted to a scoreboard (the score is already numeric).
- An `intro`/hint TUI that presents the challenge and re-grades on demand.
- Wire `chaos/*.sh break` into each challenge so `make grade` injects the fault too.
- Timed grading → an MTTR-scored incident mode (pairs with the AI incident copilot).
