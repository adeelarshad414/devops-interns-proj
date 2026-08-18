#!/usr/bin/env python3
"""Offline test of the grader engine - deterministic, no live stack, no network.

Run in CI on every PR:
  * the self-test challenge must FULLY pass (every check type dispatches + scores);
  * a deliberately-failing challenge must be reported as unsolved with the hint;
  * scoring maths is exact.
Exits non-zero on any failure so it gates the build.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
os.chdir(ROOT)  # file/shell checks are relative to the repo root

from grader import grade, load  # noqa: E402

failures = []


def expect(cond, msg):
    if cond:
        print("  ok: " + msg)
    else:
        failures.append(msg)
        print("  FAIL: " + msg)


# 1. The self-test challenge fully passes and awards full points.
challenge = load(os.path.join("challenges", "_selftest.yml"))
earned, total, results = grade(challenge)
expect(all(r["passed"] for r in results), "every self-test check passes")
expect(abs(earned - total) < 1e-6, "full score awarded ({0:.0f}/{1:.0f})".format(earned, total))
expect(len(results) == len(challenge["checks"]), "one result per check")

# 2. A deliberately-failing challenge is reported as unsolved, with partial score.
broken = {
    "id": "negative",
    "title": "negative path",
    "points": 40,
    "checks": [
        {"name": "true file", "type": "file", "path": "README.md", "exists": True},
        {"name": "missing file", "type": "file", "path": "nope/nope.txt", "exists": True,
         "hint": "this hint should surface"},
        {"name": "bad exit", "type": "shell", "cmd": "exit 3", "hint": "shell should fail"},
        {"name": "unknown type", "type": "does-not-exist"},
    ],
}
earned, total, results = grade(broken)
passed_flags = [r["passed"] for r in results]
expect(passed_flags == [True, False, False, False], "exactly the one valid check passes")
expect(abs(earned - (total / 4)) < 1e-6, "partial score = 1/4 of points")
expect(results[1]["hint"] == "this hint should surface", "the failing check carries its hint")

# 3. Each check TYPE is exercised at least once across the two challenges above
#    (file, shell were in both; prove http/prometheus dispatch cleanly when the
#    target is unreachable - they must fail gracefully, never raise).
from checks import run_check  # noqa: E402
ok, _ = run_check({"type": "http", "url": "http://127.0.0.1:1/nope"})
expect(ok is False, "http check fails gracefully when unreachable")
ok, _ = run_check({"type": "prometheus", "query": "up", })
expect(ok is False, "prometheus check fails gracefully when unreachable")

print()
if failures:
    print("{0} assertion(s) failed".format(len(failures)))
    sys.exit(1)
print("all grader engine tests passed")
