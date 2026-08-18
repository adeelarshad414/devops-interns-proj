#!/usr/bin/env python3
"""Grade the copilot against labelled fixtures.

For each fixture we know the ground-truth root_cause_id. We run one or both
reasoners over the evidence and score:

  accuracy@1 - did the TOP hypothesis match ground truth?
  accuracy@3 - was ground truth anywhere in the top 3?

The heuristic baseline always runs (offline, deterministic). The Claude reasoner
runs too when ANTHROPIC_API_KEY is set - and the whole point is to see whether the
model BEATS the baseline, and by how much. In CI this doubles as an evals-as-a-gate:
`--min-acc1` fails the run if the (LLM, when keyed) accuracy@1 drops below a floor.

  python run_evals.py                 # baseline always; Claude if a key is set
  python run_evals.py --min-acc1 0.8  # also enforce a floor on the graded reasoner
"""
import argparse
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from reasoner import ClaudeReasoner, HeuristicReasoner  # noqa: E402

FIXTURE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")


def load_fixtures():
    cases = []
    for path in sorted(glob.glob(os.path.join(FIXTURE_DIR, "*.json"))):
        with open(path) as f:
            doc = json.load(f)
        cases.append((os.path.basename(path), doc["evidence"], doc["ground_truth"]))
    return cases


def grade(reasoner, cases):
    rows, hit1, hit3 = [], 0, 0
    for name, evidence, truth in cases:
        try:
            result = reasoner.analyze(evidence)
            ids = [h.get("root_cause_id") for h in result.get("hypotheses", [])]
        except Exception as e:  # a dead reasoner scores zero, it does not crash the run
            ids = []
            rows.append((name, truth, "ERROR: {0}".format(e)[:40], False, False))
            continue
        top1 = bool(ids) and ids[0] == truth
        top3 = truth in ids[:3]
        hit1 += top1
        hit3 += top3
        rows.append((name, truth, (ids[0] if ids else "-"), top1, top3))
    n = len(cases)
    return rows, (hit1 / n if n else 0.0), (hit3 / n if n else 0.0)


def print_scorecard(title, rows, acc1, acc3):
    print("\n=== {0} ===".format(title))
    print("{0:22} {1:26} {2:26} {3}".format("fixture", "ground_truth", "top hypothesis", "@1 @3"))
    for name, truth, top, t1, t3 in rows:
        print("{0:22} {1:26} {2:26} {3}  {4}".format(
            name, truth, top, "OK" if t1 else "  ", "OK" if t3 else "  "))
    print("accuracy@1 = {0:.0%}    accuracy@3 = {1:.0%}".format(acc1, acc3))


def main(argv=None):
    p = argparse.ArgumentParser(description="Grade the incident copilot")
    p.add_argument("--min-acc1", type=float, default=None,
                   help="Fail (exit 1) if the graded reasoner's accuracy@1 is below this.")
    args = p.parse_args(argv)

    cases = load_fixtures()
    print("Loaded {0} labelled fixtures.".format(len(cases)))

    # Baseline always.
    b_rows, b1, b3 = grade(HeuristicReasoner(), cases)
    print_scorecard("BASELINE (heuristic)", b_rows, b1, b3)

    graded_acc1 = b1  # what the gate checks; the LLM takes over when available
    graded_name = "heuristic"
    if os.environ.get("ANTHROPIC_API_KEY"):
        c_rows, c1, c3 = grade(ClaudeReasoner(), cases)
        print_scorecard("CLAUDE", c_rows, c1, c3)
        print("\nLLM vs baseline: accuracy@1 {0:+.0%}".format(c1 - b1))
        graded_acc1, graded_name = c1, "claude"
    else:
        print("\n(ANTHROPIC_API_KEY not set - skipping the Claude reasoner; baseline only.)")

    if args.min_acc1 is not None and graded_acc1 < args.min_acc1:
        print("\nGATE FAILED: {0} accuracy@1 {1:.0%} < floor {2:.0%}".format(
            graded_name, graded_acc1, args.min_acc1))
        return 1
    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
