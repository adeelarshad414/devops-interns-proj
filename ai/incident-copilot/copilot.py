#!/usr/bin/env python3
"""AI SRE Incident Copilot - CLI.

Collect an evidence bundle (live from the observability stack, or from a recorded
fixture), ask a reasoner for ranked root-cause hypotheses, and print a pager-ready
report.

  python copilot.py --fixture evals/fixtures/latency-n1.json   # offline, deterministic
  python copilot.py --live                                     # against Prometheus/Loki/Tempo
  python copilot.py --live --mock                              # live evidence, heuristic reasoner

Reasoner selection: Claude when ANTHROPIC_API_KEY is set (unless --mock), else the
heuristic baseline. See reasoner.py.
"""
import argparse
import json
import sys

from reasoner import get_reasoner


def _bar(conf):
    filled = int(round(max(0.0, min(1.0, conf)) * 10))
    return "[" + "#" * filled + "-" * (10 - filled) + "]"


def render(result, reasoner_name):
    lines = []
    lines.append("=" * 72)
    lines.append("  AI SRE INCIDENT COPILOT   (reasoner: {0})".format(reasoner_name))
    lines.append("=" * 72)
    lines.append("SUMMARY: " + result.get("summary", "(none)"))
    lines.append("")
    for i, h in enumerate(result.get("hypotheses", []), 1):
        lines.append("#{0}  {1}  {2} {3:.0%}".format(
            i, h.get("title", h.get("root_cause_id")), _bar(h.get("confidence", 0)), h.get("confidence", 0)))
        lines.append("    root_cause_id : {0}".format(h.get("root_cause_id")))
        for s in h.get("supporting_signals", []):
            lines.append("    signal        : {0}".format(s))
        lines.append("    next step      : {0}".format(h.get("suggested_next_step", "")))
        lines.append("    suggested fix  : {0}".format(h.get("suggested_fix", "")))
        lines.append("")
    lines.append("-" * 72)
    lines.append("NB: hypotheses are advisory. Confirm with the suggested next step")
    lines.append("    before acting - the copilot is graded, not trusted. See README.")
    return "\n".join(lines)


def main(argv=None):
    p = argparse.ArgumentParser(description="AI SRE Incident Copilot")
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--fixture", help="Path to a recorded evidence-bundle JSON file.")
    src.add_argument("--live", action="store_true", help="Collect live from Prometheus/Loki/Tempo.")
    p.add_argument("--mock", action="store_true", help="Force the heuristic reasoner (no API call).")
    p.add_argument("--json", action="store_true", help="Emit the raw JSON result instead of the report.")
    args = p.parse_args(argv)

    if args.fixture:
        with open(args.fixture) as f:
            doc = json.load(f)
        # A fixture is either a bare evidence bundle or {evidence, ground_truth}.
        evidence = doc.get("evidence", doc) if isinstance(doc, dict) else doc
    else:
        from collectors import collect
        evidence = collect()

    reasoner = get_reasoner(force_mock=args.mock)
    result = reasoner.analyze(evidence)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(render(result, reasoner.name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
