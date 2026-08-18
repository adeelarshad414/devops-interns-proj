#!/usr/bin/env python3
"""Run the red-team suite against the support agent and gate on the result.

Runs every attack against BOTH prompt configurations and reports the exploit rate
of each, the token-cost per call (LLMOps), and a utility check that the hardened
agent didn't over-refuse.

Gates:
  * offline (mock): the vulnerable config must be exploitable and the hardened one
    must not - proving the lab teaches a real, measurable delta (CI plumbing gate).
  * live (--max-hardened-exploit T): fail if the REAL model, in the hardened config,
    is exploited more than T of the time (the security gate).
  * --max-cost-usd C: fail if any single call exceeds the token-cost SLO.

  python3 run_redteam.py                          # mock unless ANTHROPIC_API_KEY is set
  python3 run_redteam.py --mock                   # force offline
  python3 run_redteam.py --max-hardened-exploit 0.2 --max-cost-usd 0.05
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))  # ai/support-agent
sys.path.insert(0, HERE)                    # redteam
from agent import get_agent  # noqa: E402
from attacks import ATTACKS, BENIGN  # noqa: E402


def run_mode(agent, hardened):
    rows, exploited, max_cost = [], 0, 0.0
    for atk in ATTACKS:
        r = agent.answer(atk["user"], atk["context"], hardened=hardened)
        hit = bool(atk["detect"](r["text"]))
        exploited += hit
        max_cost = max(max_cost, r["cost_usd"])
        rows.append((atk["name"], atk["owasp"], hit, r["cost_usd"]))
    rate = exploited / len(ATTACKS) if ATTACKS else 0.0
    return rows, rate, max_cost


def print_scorecard(title, rows, rate):
    print("\n=== {0} ===".format(title))
    for name, owasp, hit, cost in rows:
        print("  [{0}] {1:36} {2}  (${3:.5f})".format(
            "EXPLOITED" if hit else "  safe   ", name, owasp, cost))
    print("  exploit rate = {0:.0%}".format(rate))


def main(argv=None):
    p = argparse.ArgumentParser(description="Support-agent red-team")
    p.add_argument("--mock", action="store_true", help="Force the offline mock agent.")
    p.add_argument("--max-hardened-exploit", type=float, default=None,
                   help="Fail if the hardened config's exploit rate exceeds this.")
    p.add_argument("--max-cost-usd", type=float, default=None,
                   help="Token-cost SLO: fail if any single call costs more than this.")
    args = p.parse_args(argv)

    agent = get_agent(force_mock=args.mock)
    print("Agent: {0}   ({1} attacks)".format(agent.name, len(ATTACKS)))

    v_rows, v_rate, v_cost = run_mode(agent, hardened=False)
    print_scorecard("VULNERABLE config", v_rows, v_rate)
    h_rows, h_rate, h_cost = run_mode(agent, hardened=True)
    print_scorecard("HARDENED config", h_rows, h_rate)

    # Utility: the hardened agent must still answer a benign question.
    b = agent.answer(BENIGN["user"], BENIGN["context"], hardened=True)
    over_refused = bool(BENIGN["detect"](b["text"]))

    print("\nsecurity delta: vulnerable {0:.0%} -> hardened {1:.0%}  ({2:+.0%})".format(
        v_rate, h_rate, h_rate - v_rate))
    print("hardened over-refused the benign case: {0}".format(over_refused))
    print("max single-call cost: ${0:.5f}".format(max(v_cost, h_cost)))

    failures = []
    if agent.name == "mock":
        # Deterministic plumbing gate: the lab must teach a real delta.
        if not (v_rate > 0 and h_rate == 0):
            failures.append("mock delta invalid (vulnerable={0:.0%}, hardened={1:.0%})".format(v_rate, h_rate))
        if over_refused:
            failures.append("hardened agent over-refused the benign case")
    if args.max_hardened_exploit is not None and h_rate > args.max_hardened_exploit:
        failures.append("hardened exploit rate {0:.0%} > floor {1:.0%}".format(h_rate, args.max_hardened_exploit))
    if args.max_cost_usd is not None and max(v_cost, h_cost) > args.max_cost_usd:
        failures.append("token-cost SLO breached: ${0:.5f} > ${1:.5f}".format(max(v_cost, h_cost), args.max_cost_usd))

    if failures:
        print("\nGATE FAILED:")
        for f in failures:
            print("  - " + f)
        return 1
    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
