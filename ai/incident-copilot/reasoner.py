"""Two reasoners over an evidence bundle.

  ClaudeReasoner  - the real copilot. Sends the evidence to Claude and gets back
                    ranked, schema-validated root-cause hypotheses.
  HeuristicReasoner - a dumb, deterministic baseline. Exists for two reasons:
                    (1) it lets the eval harness and the CLI run offline with no
                        API key (plumbing test), and
                    (2) it is the BASELINE the LLM must beat - "did the model add
                        value over a handful of if-statements?" is the first
                        question any AIOps eval should answer.
"""
import json
import os

from schema import ROOT_CAUSES, HYPOTHESIS_SCHEMA

DEFAULT_MODEL = os.environ.get("COPILOT_MODEL", "claude-opus-5")

SYSTEM_PROMPT = """You are an on-call SRE incident analyst for "daig", a three-tier
food-delivery platform (web -> orders -> kitchen -> dispatch -> postgres/redis).

You are given an evidence bundle: SLO targets, a snapshot of Prometheus metrics,
the top recent log lines, and trace summaries. Produce ranked root-cause
hypotheses.

Rules:
- Choose root_cause_id ONLY from the provided taxonomy. Do not invent categories.
- Quote the SPECIFIC signals from the evidence that support each hypothesis
  (e.g. "dispatch p95 = 3.9s vs 1s SLO", "42 sequential DB spans in the assign trace").
- If every signal is within SLO and nothing is anomalous, return a single
  "no-incident" hypothesis. Do NOT invent an incident to look useful - a false page
  is a real cost.
- Order hypotheses by confidence, most likely first, at most 3.
- suggested_next_step is the single most useful diagnostic to confirm/refute.
- Be concrete and terse. This goes to a pager, not a blog post."""


def _taxonomy_block():
    lines = ["Root-cause taxonomy (id -> meaning -> runbook):"]
    for rid, meta in ROOT_CAUSES.items():
        lines.append("  {0}: {1}  [runbook: {2}]".format(rid, meta["label"], meta["runbook"]))
    return "\n".join(lines)


def build_prompt(evidence):
    return (
        _taxonomy_block()
        + "\n\nEvidence bundle:\n"
        + json.dumps(evidence, indent=2)
        + "\n\nReturn ranked root-cause hypotheses as JSON matching the schema."
    )


class ClaudeReasoner:
    name = "claude"

    def __init__(self, model=None):
        self.model = model or DEFAULT_MODEL

    def analyze(self, evidence):
        import anthropic  # lazy: only needed on the live path

        client = anthropic.Anthropic()
        resp = client.messages.create(
            model=self.model,
            max_tokens=4096,  # room for adaptive thinking (on by default) + the JSON
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": build_prompt(evidence)}],
            output_config={"format": {"type": "json_schema", "schema": HYPOTHESIS_SCHEMA}},
        )
        # Opus 5 safety classifiers can decline - check before reading content.
        if resp.stop_reason == "refusal":
            raise RuntimeError("model refused: {0}".format(getattr(resp, "stop_details", None)))
        text = next(b.text for b in resp.content if b.type == "text")
        return json.loads(text)


class HeuristicReasoner:
    """Deterministic baseline. Same output shape as ClaudeReasoner."""

    name = "heuristic"

    def analyze(self, evidence):
        m = evidence.get("metrics", {})
        slo = evidence.get("slo", {})
        logs = evidence.get("logs", [])
        traces = evidence.get("traces", [])
        hyps = []

        def add(rid, conf, signals, nxt):
            hyps.append({
                "root_cause_id": rid,
                "title": ROOT_CAUSES[rid]["label"],
                "confidence": conf,
                "supporting_signals": signals,
                "suggested_next_step": nxt,
                "suggested_fix": ROOT_CAUSES[rid]["fix"],
            })

        up = m.get("up", {})
        restarts = m.get("restarts_5m", {})
        down = [s for s, v in up.items() if v == 0]
        flapping = [s for s, v in restarts.items() if v and v >= 2]
        lat_target = slo.get("latency_p95_target_s", 1.0)

        if down or flapping:
            add("service-crashloop", 0.8,
                ["down={0}".format(down), "restarts_5m={0}".format({k: restarts[k] for k in flapping})],
                "kubectl -n daig get pods; check the last logs + exit code of the failing pod.")

        log_text = " ".join((l.get("msg", "") + " " + l.get("level", "")) for l in logs).lower()
        if any(w in log_text for w in ("dns", "connection refused", "unreachable", "timeout", "econnrefused")):
            add("network-db-unreachable", 0.7,
                ["error keywords in recent logs"],
                "Curl the dependency from inside a pod; check NetworkPolicy / DNS.")

        d_p95 = m.get("dispatch_p95_latency_s")
        n1_trace = next((t for t in traces if t.get("db_spans", 0) >= 10), None)
        if d_p95 and d_p95 > lat_target and n1_trace:
            add("dispatch-n1-query", 0.85,
                ["dispatch p95={0}s vs {1}s SLO".format(d_p95, lat_target),
                 "{0} sequential DB spans in {1}".format(n1_trace.get("db_spans"), n1_trace.get("name"))],
                "Open the slow assign trace; count the per-rider count queries.")

        k_cpu = m.get("kitchen_cpu_cores")
        if k_cpu and k_cpu >= 0.8:
            add("kitchen-surge-cpu-loop", 0.8,
                ["kitchen cpu={0} cores (saturated)".format(k_cpu)],
                "Grab a CPU profile of kitchen; look for computeSurgeScore in the flame graph.")

        avail = m.get("orders_availability_ratio5m", 1.0)
        avail_target = slo.get("availability_target", 0.999)
        if avail < avail_target and not hyps:
            add("orders-elevated-errors", 0.6,
                ["orders availability={0} < {1} SLO".format(avail, avail_target)],
                "Read the failing order trace to find the erroring dependency.")

        if not hyps:
            add("no-incident", 0.9, ["all sampled signals within SLO"],
                "None. Keep watching the burn-rate panels.")

        hyps.sort(key=lambda h: h["confidence"], reverse=True)
        top = hyps[0]["root_cause_id"]
        summary = "No incident detected." if top == "no-incident" else \
            "Likely {0}.".format(ROOT_CAUSES[top]["label"])
        return {"summary": summary, "hypotheses": hyps[:3]}


def get_reasoner(force_mock=False):
    """Claude when an API key is available (and not forced to mock), else the baseline."""
    if not force_mock and os.environ.get("ANTHROPIC_API_KEY"):
        return ClaudeReasoner()
    return HeuristicReasoner()
