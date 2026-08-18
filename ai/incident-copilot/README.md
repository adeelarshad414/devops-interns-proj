# AI SRE Incident Copilot 🤖🚨

A proof-of-concept **AIOps** tool for this platform: during an incident it reads the
live observability signals, and proposes **ranked root-cause hypotheses** with the
evidence behind each one and the next diagnostic to run — then an **eval harness
grades how often it's right**.

It exists to teach two things at once:

1. **AIOps** — turning metrics + logs + traces into a triage decision, the way an
   on-call engineer does, but in seconds.
2. **LLM evaluation** — an LLM in the incident path is only trustworthy if you
   *measure* it. This POC ships its own scorecard and compares the model against a
   dumb heuristic baseline. "Does the AI beat five if-statements?" is the first
   question, and here you can answer it.

It ties together the five domains this repo covers: **AI + SRE + observability +
Kubernetes + the chaos scenarios.**

---

## How it works

```
  observability stack                 reasoner                 you
 ┌───────────────────┐   evidence   ┌───────────┐  ranked   ┌──────────┐
 │ Prometheus  (RED, │   bundle     │  Claude   │  root-    │  pager-  │
 │  SLO rules)       │ ───────────▶ │  (or the  │  cause    │  ready   │
 │ Loki  (errors)    │  metrics +   │ heuristic │  hypo-    │  report  │
 │ Tempo (slow trace)│  logs +      │ baseline) │  theses   │          │
 └───────────────────┘  traces      └───────────┘           └──────────┘
        collectors.py                reasoner.py             copilot.py
```

- **`collectors.py`** builds an *evidence bundle* from Prometheus (the very SLO
  recording rules in [`observability/rules/slo.yml`](../../observability/rules/slo.yml)),
  Loki, and Tempo. Every source is best-effort — a copilot that crashes when Loki
  is down is useless exactly when you need it. Stdlib only.
- **`reasoner.py`** turns that bundle into ranked hypotheses. Two implementations:
  - `ClaudeReasoner` — the real thing (Anthropic SDK, structured output).
  - `HeuristicReasoner` — a deterministic baseline of a few `if` statements, so the
    tool runs offline **and** so the eval has something to beat.
- **`schema.py`** — the closed root-cause taxonomy (mapped to the repo's chaos
  scenarios + runbooks) and the JSON schema the model must return.
- **`evals/`** — labelled fixtures + `run_evals.py`, the scorecard.

## Run it

```bash
# Offline, deterministic — recorded evidence, heuristic reasoner. No key, no deps.
python3 ai/incident-copilot/copilot.py --fixture ai/incident-copilot/evals/fixtures/latency-n1.json --mock

# The real copilot on a recorded incident (needs a key + the SDK):
export ANTHROPIC_API_KEY=...
pip install -r ai/incident-copilot/requirements.txt
python3 ai/incident-copilot/copilot.py --fixture ai/incident-copilot/evals/fixtures/latency-n1.json

# Live, against a running stack (docker compose -f docker-compose.obs.yml up):
python3 ai/incident-copilot/copilot.py --live
```

Or via the Makefile: `make copilot` (demo on a fixture) and `make copilot-eval`
(the scorecard).

Reasoner selection: **Claude when `ANTHROPIC_API_KEY` is set** (unless `--mock`),
otherwise the heuristic baseline.

## The eval — evals-as-a-gate

```bash
python3 ai/incident-copilot/evals/run_evals.py
```

It scores every fixture on **accuracy@1** (top hypothesis correct) and
**accuracy@3** (ground truth in the top three), prints a scorecard for the baseline
and — when a key is present — for Claude, and reports the **delta between them**.
`--min-acc1 0.8` turns it into a CI gate that fails the build if the graded
reasoner regresses. The repo's CI runs the offline baseline eval on every PR
(plumbing) and the live Claude eval only when the `ANTHROPIC_API_KEY` secret is
configured — the same "skip when the secret is absent" pattern as the SonarQube gate.

## Honest limitations (read this)

This is a POC, and the honesty discipline from [`VERIFICATION.md`](../../VERIFICATION.md)
applies:

- **The copilot will be wrong sometimes.** That is *why* the eval exists. Treat its
  output as a ranked starting point, confirm with the suggested next step, and never
  wire it to take an action on its own.
- **Taxonomy-bounded.** It classifies into known runbook categories; it will not
  diagnose a novel incident it has never seen a pattern for (it should say
  `unknown` — whether it actually does is exactly what the eval measures).
- **Small fixture set.** Five scenarios. A real deployment needs dozens, refreshed
  from real post-mortems, plus adversarial "looks-like-X-but-isn't" cases.
- **Prompt-injectable in theory.** Log lines are attacker-influenced data. This POC
  treats them as untrusted text, but a hardened version needs the AI-security
  controls this repo teaches elsewhere applied to the log content itself.
- **Token cost.** Each live run is an API call. Fine for incidents; don't poll it.

## Where to take it next

- Add exemplar trace IDs so a hypothesis links straight to the trace (the
  spanmetrics exemplars are already wired in `observability/otel-collector.yaml`).
- Feed CD deploy markers into `recent_deploys` — half of RCA is "what changed?".
- A verifier pass: a second call that tries to *refute* the top hypothesis before it
  reaches the pager (the adversarial-verify pattern).
