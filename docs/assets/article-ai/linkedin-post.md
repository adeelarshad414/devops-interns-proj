# LinkedIn post (short) — pairs with cover.png

*(Attach `cover.png`, or the 4 PNGs as a carousel: cover → solution → flow-copilot → flow-redteam.)*

---

I turned my open-source DevOps teaching platform (Daig) into something that
**measures itself.** 🧪

Not "I added AI." Four AI-native capabilities — and every one ships as an **eval or
a gate wired into CI.** A number that can fail the build.

🤖 **AI Incident Copilot (AIOps)** — reads live Prometheus/Loki/Tempo during an
incident, ranks root-cause hypotheses, and **grades itself** (accuracy@1/@3 vs a
heuristic baseline). Graded, not trusted.

🥊 **Auto-grader arena** — a challenge injects a fault, you fix it, the grader probes
live state and **scores your fix, per check, with a hint on every miss.** One engine
→ a lab, a CI gate, or a scoreboard.

🛡️ **LLMOps + AI-security lab** — a support agent built vulnerable *and* hardened
against the OWASP-LLM Top 10, with a red-team gate that measures the delta
(**100% → 0% exploit**) and a **per-call token-cost SLO.**

💸 **Infracost cost gate (FinOps)** — every infra PR gets a monthly-cost diff + a
guardrail that **fails the build past a $ threshold.** Cost as a CI signal.

The through-line: offline-testable, secret-gated, and enforced as a number — the
platform is **measured, not just read.** (CI even caught two of my own bugs before
merge. The gates work on the author too. 😅)

All open-source — code, evals, CI workflows, diagrams:
👉 github.com/adeelarshad414/devops-interns-proj

If you were adding an AI-native capability to *your* platform — what would you
measure first?

#DevOps #SRE #AIOps #LLMOps #DevSecOps #PlatformEngineering #FinOps #Observability
