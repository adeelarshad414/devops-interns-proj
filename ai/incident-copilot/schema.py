"""Shared taxonomy and the JSON schema the reasoner must return.

The taxonomy is deliberately small and closed. A production incident copilot maps
symptoms onto a KNOWN set of runbook categories, not free text - that is what makes
its output gradeable against ground truth and actionable against a runbook. Each id
below corresponds to a chaos scenario this platform can actually inject
(see chaos/*.sh and the CHAOS_* flags in services/).
"""

# root_cause_id -> human label + the runbook pointer the copilot should cite.
ROOT_CAUSES = {
    "dispatch-n1-query": {
        "label": "Dispatch N+1 query (missing index on assignments.rider_id)",
        "runbook": "docs/DAY4.md#orders-slow",
        "fix": "Unset CHAOS_SLOW_DISPATCH / add an index on assignments(rider_id).",
    },
    "kitchen-surge-cpu-loop": {
        "label": "Kitchen surge-pricing O(n^2) CPU hot loop",
        "runbook": "docs/DAY4.md",
        "fix": "Unset CHAOS_HOT_SURGE_LOOP; replace the double loop with the Map-based tally.",
    },
    "service-crashloop": {
        "label": "A service is crash-looping / failing readiness",
        "runbook": "docs/DAY3.md",
        "fix": "Check the pod's last logs and exit code; fix the boot failure, then let the rollout heal.",
    },
    "network-db-unreachable": {
        "label": "Network partition / database unreachable",
        "runbook": "docs/DAY1.md",
        "fix": "Restore connectivity (DNS / NetworkPolicy / the injected partition), then verify readyz.",
    },
    "orders-elevated-errors": {
        "label": "Orders elevated error rate (burning error budget)",
        "runbook": "docs/DAY4.md#orders-failing",
        "fix": "Follow the fast-burn runbook: identify the failing dependency from the trace.",
    },
    "no-incident": {
        "label": "No incident - signals are within SLO",
        "runbook": "-",
        "fix": "No action. Do not page.",
    },
    "unknown": {
        "label": "Unknown - evidence does not match a known pattern",
        "runbook": "-",
        "fix": "Escalate to a human; gather more signals (profile, more traces).",
    },
}

ROOT_CAUSE_IDS = list(ROOT_CAUSES.keys())

# The structured-output schema. Kept within the documented constraints: every
# object sets additionalProperties:false + required, and root_cause_id is an enum.
# (No minItems/maxItems - array-length constraints aren't supported; the prompt
# asks for the top 3.)
HYPOTHESIS_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "summary": {
            "type": "string",
            "description": "One sentence: what is happening, from the customer's point of view.",
        },
        "hypotheses": {
            "type": "array",
            "description": "Root-cause hypotheses, most likely first (aim for up to 3).",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "root_cause_id": {"type": "string", "enum": ROOT_CAUSE_IDS},
                    "title": {"type": "string"},
                    "confidence": {
                        "type": "number",
                        "description": "0.0-1.0 confidence in this hypothesis.",
                    },
                    "supporting_signals": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Specific metrics/logs/traces from the evidence that support this.",
                    },
                    "suggested_next_step": {
                        "type": "string",
                        "description": "The single most useful diagnostic to confirm or refute this.",
                    },
                    "suggested_fix": {"type": "string"},
                },
                "required": [
                    "root_cause_id",
                    "title",
                    "confidence",
                    "supporting_signals",
                    "suggested_next_step",
                    "suggested_fix",
                ],
            },
        },
    },
    "required": ["summary", "hypotheses"],
}
