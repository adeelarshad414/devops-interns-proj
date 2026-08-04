# DevSecOps

## The framing that matters

DevSecOps is not a tool list and it is not a person. It is one claim:

> **Security checks belong in the pipeline, run automatically, and have the
> authority to stop a release.**

Everything else follows from that. A scanner whose output nobody reads is not
DevSecOps. A security review that happens after the code ships is not
DevSecOps. A gate that blocks a merge, on every merge, without anyone
remembering to run it — that is DevSecOps.

Say this to interns first, because most of them arrive thinking security is a
separate team that says no. The reframe is: **security is a test.** You already
accept that a failing unit test blocks a merge. This is the same thing with a
different assertion.

---

## Where it lives in the week

Security is not a day. It is a thread through every day, plus one concentrated
block.

| Day | The security thread |
|---|---|
| **1 — Linux** | File permissions, users and groups, why `readOnlyRootFilesystem` needs a `/tmp` mount, SSH key auth vs passwords |
| **2 — Cloud/Terraform** | Security groups as the three-tier boundary, least-privilege IAM, secrets never in tfvars, `tfsec` on your own plan, IMDSv2 |
| **3 — Docker/Ansible** | Non-root containers, capability dropping, image layers remember secrets forever, `no_log` in Ansible |
| **4 — CI/CD** | **The concentrated block.** The full gate chain. See below. |
| **5 — Kubernetes** | Pod security, NetworkPolicy, Kyverno admission control, signed images |

**If you have a sixth day, this earns it.** The `docs/COVERAGE.md` scope note
applies here too: DevSecOps done properly is a day of its own, and squeezing it
into Day 4 alongside CI/CD and observability is how it becomes a slide instead
of a skill.

---

## The gate chain, ordered by cost of feedback

`.github/workflows/devsecops.yml` runs these in this order, and the *order* is
the lesson:

| # | Gate | Tool | Catches | Runs in |
|---|---|---|---|---|
| 1 | Secrets | gitleaks | Credentials in code or history | ~20s |
| 2 | SAST | Semgrep, CodeQL | Vulnerable code patterns | ~1–3m |
| 3 | SCA | npm audit, OSV | Vulnerable dependencies | ~1m |
| 4 | IaC + policy | Trivy, Checkov, Conftest/OPA | Misconfigured infrastructure | ~1m |
| 5 | Image + supply chain | Trivy, syft, cosign | Vulnerable images; unsigned artifacts | ~3m |
| 6 | DAST | OWASP ZAP | Runtime behaviour of a live app | ~5m |
| — | Runtime | Falco | Things that get through anyway | continuous |

**Why this order.** Cheapest and fastest first. A leaked key must never merge
and takes 20 seconds to detect, so it goes first. DAST needs the whole stack up
and takes minutes, so it goes last. If a developer waits twelve minutes to learn
about a typo, they stop trusting the pipeline — and **a pipeline people work
around protects nobody.** That sentence is the most useful thing on this page.

---

## Hands-on: the six vulnerabilities

Daig ships with six real, deliberate vulnerabilities in
`services/orders/src/insecure.js`, gated behind `INSECURE_MODE=true` and
refusing to load at all when `NODE_ENV=production`.

```bash
./chaos/day6-security.sh break     # enable them
./security/scan-all.sh             # run the whole toolchain
./chaos/day6-security.sh verify    # see which are still exploitable
./chaos/day6-security.sh hints     # progressive hints if stuck
```

| # | CWE | Vulnerability | Found by |
|---|---|---|---|
| 1 | CWE-89 | SQL injection via string concatenation | Semgrep, CodeQL, ZAP |
| 2 | CWE-639 | Broken object-level authorisation (IDOR) | **nothing** |
| 3 | CWE-209 | Stack trace and connection string in the response | Semgrep, ZAP |
| 4 | CWE-327 | MD5 as a password hash | Semgrep, CodeQL |
| 5 | CWE-770 | No rate limiting | nothing automated |
| 6 | CWE-918 | SSRF with no allowlist | Semgrep, CodeQL |

### The exercise is five steps, and step 3 is the point

1. **Run the tools.** Get the raw output.
2. **Triage.** For each finding: is it real, is it reachable, what does it
   actually let someone do *here*? A finding is not a vulnerability until you
   can state the impact.
3. **Find the one the tools missed.** Five of six get flagged. VULN-2 does not.
4. **Fix three properly.** Each vulnerable handler has the correct
   implementation in a comment beneath it. Understand why it is the fix — the
   answer to SQL injection is not "escape the input", it is "never concatenate".
5. **Add a gate.** Write a Semgrep rule, an OPA policy, or a test that makes
   the fix permanent.

**Step 5 is what separates DevSecOps from security.** A fix without a gate
regresses within two sprints. Say that, then make them write the rule.

### Why VULN-2 matters more than the other five

The IDOR has parameterised SQL, no unsafe call, and nothing any scanner can
point at. The code is not wrong in any local sense. What is *missing* is a
business rule: nobody checked that the requester owns the order.

No tool finds it, because "who should be allowed to see this" is knowledge about
your business that a scanner cannot have. It is #1 on the OWASP API Security
Top 10 for precisely this reason.

The conclusion to land: **tools find classes of bug; humans find missing rules.**
Code review is not a formality you perform once the scanners are green.

---

## Secrets: the compromise and the real answer

This repository uses `CHANGE_ME_DEV_ONLY` placeholders everywhere, registered in
`DUMMY-VALUES.md`, with a startup guard that exits **78** if a dummy survives
into production.

That is a teaching compromise, and interns should be told so. Then show them
what production does:

```bash
docker compose -f docker-compose.yml -f docker-compose.security.yml up -d openbao
./security/vault-demo.sh
```

The part that changes how they think is **dynamic credentials**: instead of one
long-lived password shared by every instance, the secret store creates a
database user per request with a TTL. Ask the room what a one-hour TTL does to
an attacker who exfiltrates a `.env` file. That question does more than an hour
of explanation.

---

## Supply chain

```bash
./security/sign-and-verify.sh ghcr.io/adeelarshad414/daig/orders:sha
```

Three ideas, in order:

1. **SBOM.** A list of everything in the image. Useless on the day you generate
   it; the only thing that answers "which of our 200 services ships that
   library" on the day the next Log4Shell lands.
2. **Provenance (SLSA).** A signed record of *how* the artifact was built —
   which commit, which workflow, which runner.
3. **Signing (cosign, keyless).** There is no private key. The signing identity
   is the CI workflow, proven by an OIDC token, so a valid signature means "this
   came from that pipeline". Nothing to steal, rotate, or leak.

Then close the loop: `security/kyverno/policies.yaml` refuses to admit an
unsigned image to the cluster. Signing that nothing verifies is a ritual.

The script deliberately ends by trying to verify an image nobody signed, and
failing. **Watch a check fail.** A gate that has never failed in front of you
proves nothing.

---

## Policy as code, in two places on purpose

The same rules exist twice, and the duplication is deliberate:

- `security/policy/*.rego` — Conftest, at **CI time**
- `security/kyverno/policies.yaml` — Kyverno, at **admission time**

CI protects you from mistakes. Admission control protects you from *bypass* —
`kubectl apply` from a laptop, a vendor Helm chart, an operator creating pods on
your behalf. Neither replaces the other, and understanding why is worth ten
minutes of Day 5.

Kyverno also **mutates**, not just blocks: `daig-add-default-labels` adds cost
attribution automatically. That is the platform engineer's move from the kickoff
deck — do not ask people to remember, make the correct thing happen by default.

---

## Runtime security: the gap everything else leaves

Every gate above runs before deployment. Falco runs after.

That gap matters because a supply-chain compromise passes every pre-deploy check
*by definition* — that is what makes it a supply-chain compromise. Falco watches
for a shell spawned in a container, a package manager running at runtime, a
write below `/etc`, an unexpected outbound connection.

`security/falco/rules.yaml` includes a rule for access to `169.254.169.254`, the
cloud metadata endpoint. That is VULN-6 being exploited for credentials, caught
at runtime. Connect the two explicitly — it is the clearest demonstration in the
whole repo that pre-deploy and runtime answer different questions.

Falco needs kernel access and may not run on Docker Desktop for macOS. If it
does not start, treat it as DEMO and show a recorded run rather than losing
twenty minutes.

---

## What to say at the end

> None of these tools will make your code secure. They make *some categories of
> insecurity* expensive to ship, which is different and still worth a great deal.
>
> The vulnerability that hurts you will be the one no tool understands, because
> it will be about your business rules. That is why you still read each other's
> code.
