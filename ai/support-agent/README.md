# LLMOps + AI-security lab 🛡️🤖

A support-assistant feature for daig, built **twice**: a **vulnerable** version that
makes real [OWASP LLM Top 10](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
mistakes, and a **hardened** version that fixes them — with a **red-team harness that
measures the difference** and a **token-cost SLO** on every call.

It's the LLM-era counterpart to [`services/orders/src/insecure.js`](../../services/orders/src/insecure.js):
broken on purpose, labelled in place, and gated so the vulnerable behaviour can't
ship. And it teaches **LLMOps** — an LLM feature is only shippable if you *evaluate*
its security and *watch* its cost, both wired into CI here.

## The planted vulnerabilities (and their fixes)

| OWASP | Vulnerable version | Hardened version |
|-------|--------------------|------------------|
| **LLM01 Prompt Injection** | Untrusted order notes are concatenated raw into the prompt — an instruction hidden in a customer's order note is obeyed. | Untrusted content is **spotlighted**: fenced, labelled `<<UNTRUSTED_DATA>>`, and the model is told never to follow instructions inside it. |
| **LLM06 Sensitive Disclosure** | A staff coupon (canary) sits in the system prompt and leaks on request. | No secret in the prompt at all; the model is told never to reveal system content. |
| **LLM02 Insecure Output Handling** | The model may emit `ACTION: refund <id>` as free text that the app would execute. | The model cannot emit actions; the caller validates output separately. |

Both are in [`prompts.py`](prompts.py). The "secret" is a fake teaching canary.

## Run it

```bash
# Offline, deterministic — the mock proves the vulnerable→hardened delta, no key needed.
make redteam
python3 ai/support-agent/redteam/run_redteam.py

# Against the real model:
export ANTHROPIC_API_KEY=...
pip install -r ai/support-agent/requirements.txt
python3 ai/support-agent/redteam/run_redteam.py --max-hardened-exploit 0.2 --max-cost-usd 0.10
```

Output: the exploit rate of each configuration, per attack, plus the security delta,
an over-refusal check on a benign question, and the per-call token cost.

```
security delta: vulnerable 100% -> hardened 0%  (-100%)
```

## Evals-as-a-gate (and cost-as-a-gate)

The [`ai-security.yml`](../../.github/workflows/ai-security.yml) workflow runs the
red-team on every PR:

- **Offline** (deterministic, no key): the vulnerable config **must** be exploitable
  and the hardened one **must not**, and the hardened agent must not over-refuse the
  benign case — this guards the harness + the security delta on every PR.
- **Live** (only when `ANTHROPIC_API_KEY` is set): measures the **real model** and
  **fails the build** if the hardened config is exploited above a floor — the same
  skip-when-absent pattern as the SonarQube gate.
- **Token-cost SLO**: every call's cost is computed from a price table and the build
  fails if a call exceeds the budget (LLMOps).

## Honest limitations

- **The red-team is a starting set**, not exhaustive. Real coverage needs many more
  payloads (encodings, multi-turn, tool-abuse) refreshed as new techniques appear.
- **The mock is a deterministic stand-in** so CI runs offline; the *real* measurement
  is the live Claude run. It simulates the delta the lab teaches, it does not prove
  any particular model is safe.
- **Hardened ≠ invulnerable.** Spotlighting and instruction hierarchy raise the bar;
  they don't guarantee zero exploitability. That's exactly why the gate measures a
  *rate* against a floor rather than asserting perfection.
- The vulnerable configuration refuses to run under `NODE_ENV=production` — a
  teaching artifact, guarded like the rest of the repo's deliberate defects.

## Where to take it next

- More attack classes (obfuscated/encoded injection, multi-turn, data-exfil via tools).
- A judge-model detector instead of substring matching (LLM-as-judge for leaks).
- Wire the hardened agent into the real `web` gateway as an actual `/support` endpoint.
