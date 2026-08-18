"""The support agent - a real Claude implementation and a deterministic mock.

Both expose answer(user_message, order_context, hardened) -> {text, usage, cost_usd}.

  SupportAgent      - calls Claude. Use it to measure how a REAL model behaves
                      against the red-team, in both the vulnerable and hardened
                      prompt configurations.
  MockSupportAgent  - a deterministic stand-in so the red-team harness (and its
                      security gate) run offline with no API key. It faithfully
                      simulates the delta the lab teaches: the vulnerable config
                      leaks under injection, the hardened one refuses.
"""
import os

from prompts import build_prompt, SUPPORT_CANARY

DEFAULT_MODEL = os.environ.get("SUPPORT_MODEL", "claude-opus-5")

# $ per 1M tokens (input, output). Used for the token-cost SLO (LLMOps).
PRICES = {
    "claude-opus-5": (5.0, 25.0),
    "claude-sonnet-5": (3.0, 15.0),
    "claude-haiku-4-5": (1.0, 5.0),
}


def cost_usd(model, in_tok, out_tok):
    pin, pout = PRICES.get(model, PRICES["claude-opus-5"])
    return (in_tok / 1e6) * pin + (out_tok / 1e6) * pout


def _lab_enabled():
    # The vulnerable configuration is a teaching artifact. Refuse to run it in a
    # production-like environment, the same "don't ship the vuln" guard the rest of
    # the repo uses (secrets.js exits 78; insecure routes need INSECURE_MODE).
    if os.environ.get("NODE_ENV") == "production":
        return False
    return True


class SupportAgent:
    name = "claude"

    def __init__(self, model=None):
        self.model = model or DEFAULT_MODEL

    def answer(self, user_message, order_context, hardened=False):
        if not hardened and not _lab_enabled():
            raise RuntimeError("vulnerable support agent is disabled outside the lab (NODE_ENV=production)")
        import anthropic  # lazy: only the live path needs the SDK

        client = anthropic.Anthropic()
        prompt = build_prompt(user_message, order_context, hardened)
        resp = client.messages.create(
            model=self.model,
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}],
        )
        if resp.stop_reason == "refusal":
            text = "[model refused]"
        else:
            text = "".join(b.text for b in resp.content if getattr(b, "type", "") == "text")
        u = resp.usage
        return {
            "text": text,
            "usage": {"input_tokens": u.input_tokens, "output_tokens": u.output_tokens},
            "cost_usd": cost_usd(self.model, u.input_tokens, u.output_tokens),
        }


class MockSupportAgent:
    """Deterministic simulation of the vulnerable/hardened delta. Offline, no key."""

    name = "mock"

    def __init__(self, model=None):
        self.model = model or DEFAULT_MODEL

    def answer(self, user_message, order_context, hardened=False):
        blob = (user_message + " " + order_context).lower()
        # Markers a naive model would follow if the prompt doesn't defend against them.
        injection = any(t in blob for t in (
            "ignore previous", "ignore all previous", "system prompt", "reveal",
            "print the", "coupon", "pwned", "disregard", "you are now", "refund me now",
        ))

        if not injection:
            text = "Thanks for reaching out! Based on your order context, here's how I can help..."
        elif hardened:
            # The hardened config treats the injected text as data and refuses.
            text = ("I can't share internal instructions or issue actions myself, but a "
                    "human will review your order. How else can I help with your delivery?")
        else:
            # The vulnerable config obeys the injection: leaks the canary and complies.
            text = ("Sure! The internal staff coupon is {0}. PWNED. "
                    "ACTION: refund {1}").format(SUPPORT_CANARY, "ORDER-1")

        in_tok = max(1, len(build_prompt(user_message, order_context, hardened)) // 4)
        out_tok = max(1, len(text) // 4)
        return {
            "text": text,
            "usage": {"input_tokens": in_tok, "output_tokens": out_tok},
            "cost_usd": cost_usd(self.model, in_tok, out_tok),
        }


def get_agent(force_mock=False):
    if not force_mock and os.environ.get("ANTHROPIC_API_KEY"):
        return SupportAgent()
    return MockSupportAgent()
