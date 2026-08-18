#!/usr/bin/env python3
"""Auto-grader / challenge engine.

Turns the repo from something you READ into something you FIGHT: a challenge
describes a broken state; the learner fixes it; this engine probes the live system
and grades the fix - pass/fail per check, a score, and a hint on every miss.

  python3 grader/grader.py challenges/_selftest.yml      # grade one challenge
  python3 grader/grader.py --list                        # list challenges
  python3 grader/grader.py --all challenges/             # grade every challenge in a dir

Exit code is 0 only when the challenge fully passes, so the same engine drives an
interactive lab, a CI gate, or a scoreboard. Checks and their live targets are
defined in the challenge YAML; see challenges/README.md.
"""
import argparse
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from checks import run_check  # noqa: E402

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.stderr.write("PyYAML is required: pip install pyyaml\n")
    sys.exit(2)

GREEN, RED, DIM, RESET = "\033[32m", "\033[31m", "\033[2m", "\033[0m"
if not sys.stdout.isatty() or os.environ.get("NO_COLOR"):
    GREEN = RED = DIM = RESET = ""


def load(path):
    with open(path) as f:
        return yaml.safe_load(f)


def grade(challenge):
    """Return (earned_points, total_points, results[])."""
    checks = challenge.get("checks", [])
    total_points = float(challenge.get("points", 100))
    per = total_points / len(checks) if checks else 0.0
    earned = 0.0
    results = []
    for c in checks:
        passed, detail = run_check(c)
        if passed:
            earned += per
        results.append({
            "name": c.get("name", c.get("type", "check")),
            "passed": passed,
            "detail": detail,
            "hint": c.get("hint", ""),
        })
    return earned, total_points, results


def render(challenge, earned, total, results):
    lines = []
    lines.append("=" * 70)
    lines.append("  CHALLENGE: {0}".format(challenge.get("title", challenge.get("id"))))
    if challenge.get("scenario"):
        lines.append("  runbook: {0}".format(challenge["scenario"]))
    lines.append("=" * 70)
    for r in results:
        mark = GREEN + "PASS" + RESET if r["passed"] else RED + "FAIL" + RESET
        lines.append("  [{0}] {1}  {2}{3}{4}".format(mark, r["name"], DIM, r["detail"], RESET))
        if not r["passed"] and r["hint"]:
            lines.append("        hint: {0}".format(r["hint"]))
    passed_all = all(r["passed"] for r in results) and results
    verdict = GREEN + "SOLVED" + RESET if passed_all else RED + "not solved yet" + RESET
    lines.append("-" * 70)
    lines.append("  score: {0:.0f}/{1:.0f}    {2}".format(earned, total, verdict))
    return "\n".join(lines)


def grade_file(path):
    challenge = load(path)
    earned, total, results = grade(challenge)
    print(render(challenge, earned, total, results))
    return all(r["passed"] for r in results) and bool(results)


def main(argv=None):
    p = argparse.ArgumentParser(description="Challenge auto-grader")
    p.add_argument("challenge", nargs="?", help="Path to a challenge YAML file.")
    p.add_argument("--all", metavar="DIR", help="Grade every *.yml challenge in DIR.")
    p.add_argument("--list", metavar="DIR", nargs="?", const="challenges",
                   help="List challenges in DIR (default: challenges/).")
    args = p.parse_args(argv)

    if args.list is not None:
        for path in sorted(glob.glob(os.path.join(args.list, "*.yml"))):
            c = load(path)
            print("{0:28} {1:>4}pts  {2}".format(
                os.path.basename(path), c.get("points", 100), c.get("title", "")))
        return 0

    if args.all:
        paths = sorted(glob.glob(os.path.join(args.all, "*.yml")))
        ok = True
        for path in paths:
            ok = grade_file(path) and ok
            print()
        return 0 if ok else 1

    if not args.challenge:
        p.error("give a challenge file, or --all DIR, or --list")
    return 0 if grade_file(args.challenge) else 1


if __name__ == "__main__":
    sys.exit(main())
