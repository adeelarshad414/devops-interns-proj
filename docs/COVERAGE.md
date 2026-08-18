# Skill coverage - and an honest word about scope

## The problem with the target list

The full target list is nineteen skills:

> git, docker, docker compose, networks, volumes, aws, gcp, azure, terraform,
> ansible, ci/cd, logging, monitoring, metrics, profiling, sonarqube, linux,
> docker swarm, kubernetes, debugging, troubleshooting, **devsecops**

**That does not fit into five days as hands-on work, and pretending otherwise
is how a rotation produces interns who recognise twenty words and cannot do any
of them.**

DevSecOps in particular is not one skill. It is seven distinct gates (secrets,
SAST, SCA, IaC, image, DAST, runtime) plus supply-chain signing plus secrets
management. Treated seriously it is a day of its own. Treated as a bullet on
Day 4 it becomes a slide, which is the outcome this whole exercise exists to
avoid.

Five days is roughly 30 contact hours. Nineteen skills at genuine hands-on
depth is closer to 80. So the honest design decision is to assign each skill a
*depth*, not just a slot, and to be explicit with the interns about which is
which. They will respect that. They will not respect discovering it themselves
in an interview.

## Depth levels

| Level | Means | Test |
|---|---|---|
| **HANDS-ON** | They do it themselves, unaided, and produce an artifact | Could they repeat it on Monday with no help? |
| **GUIDED** | They do it, following along, with the instructor driving pace | Could they repeat it with the docs open? |
| **DEMO** | They watch it work and understand what it is for | Could they explain why it exists? |
| **AWARENESS** | Named, positioned, and honestly bounded | Do they know what they do not know? |

## The matrix

| Skill | Depth | Where | Artifact they produce |
|---|---|---|---|
| **Linux** | HANDS-ON | Day 1 all day | Written diagnosis of the network fault |
| **Troubleshooting** | HANDS-ON | Every Chaos Hour, all 5 days | 5 written diagnoses |
| **Debugging** | HANDS-ON | Day 4 PM, Day 5 PM | Before/after p95 screenshots |
| **Git** | HANDS-ON | Day 1 AM (90 min) | Merged PR, resolved conflict, completed bisect |
| **Docker** | HANDS-ON | Day 3 PM | Their own Dockerfile, image shrunk and measured |
| **Docker networks** | HANDS-ON | Day 3 PM | Three-tier isolation built by hand |
| **Docker volumes** | HANDS-ON | Day 3 PM | Survived `down`, destroyed with `down -v` |
| **Docker Compose** | HANDS-ON | Day 3 PM, used all week | Full stack running locally |
| **Terraform** | HANDS-ON | Day 2 all day | Applied stack + drift reconciliation |
| **CI/CD** | HANDS-ON | Day 4 AM | Pipeline that refuses a broken build |
| **Metrics** | HANDS-ON | Day 4 PM | Found the slow service from dashboards |
| **Traces** | HANDS-ON | Day 4 PM | Found the N+1 in a trace |
| **Logging** | GUIDED | Day 4 PM | Pivoted trace to logs in Grafana |
| **Profiling** | GUIDED | Day 4 PM | Found the hot function in a flame graph |
| **Monitoring / alerting** | GUIDED | Day 4 PM | Read the SLO rules; did not author them |
| **Kubernetes basics** | GUIDED | Day 5 AM | Deployed, scaled, self-healed, rolled back |
| **AWS** | GUIDED | Day 2 | One stack applied and destroyed |
| **Ansible** | GUIDED | Day 3 AM | Playbook run twice; idempotency observed |
| **Docker Swarm** | DEMO | Day 5 AM (90 min) | Scaled and rolled back a stack |
| **SonarQube** | DEMO | Day 4 AM (45 min) | Read a real report on Daig |
| **GCP** | AWARENESS | Day 2 (read the code) | Compared to the AWS stack |
| **Azure** | AWARENESS | Day 2 (read the code) | Compared to the AWS stack |
| **DevSecOps — SAST / secrets / SCA** | HANDS-ON | Day 6 (or 4a) | Triaged findings; 3 vulns fixed |
| **DevSecOps — the missed vuln (IDOR)** | HANDS-ON | Day 6 | Found what no scanner found |
| **DevSecOps — writing a gate** | HANDS-ON | Day 6 | Their own Semgrep rule or OPA policy |
| **Policy as code (OPA/Conftest)** | GUIDED | Day 6 + Day 5 | Ran policies against real manifests |
| **IaC scanning (tfsec/Checkov)** | GUIDED | Day 2 + Day 6 | Scanned their own Terraform |
| **Container scanning (Trivy)** | GUIDED | Day 3 + Day 6 | Scanned their own image |
| **Secrets management (OpenBao/Vault)** | GUIDED | Day 6 | Dynamic credential with a TTL |
| **DAST (OWASP ZAP)** | DEMO | Day 6 | Read a ZAP report; triaged it |
| **Supply chain (SBOM, cosign, SLSA)** | DEMO | Day 6 | Watched a signature verify, then fail |
| **Admission control (Kyverno)** | DEMO | Day 5 | Watched a bad pod get rejected |
| **Runtime security (Falco)** | AWARENESS | Day 6 | Understood the pre-deploy gap |

## The two decisions worth defending

**1. One cloud hands-on, three clouds read.** Applying the same stack three
times teaches almost nothing the second and third time — the concepts are
identical and only the nouns change. Applying one properly and *reading* the
other two teaches the transferable thing: that they are the same shape. An
intern who can read `infra/gcp/` after applying `infra/aws/` has learned more
than one who has clicked through three consoles.

Which cloud goes hands-on should be whichever tkxel actually bills the most
hours on. That is a business decision, not a teaching one.

**2. Swarm as DEMO, Kubernetes as GUIDED.** Ninety minutes of Swarm makes the
Kubernetes afternoon land far better, because every Kubernetes concept then has
a Swarm equivalent they already hold. But Swarm is in maintenance and nobody
should ship on it, so it earns ninety minutes and not a day. `docs/SWARM.md`
has the translation table to hand out at the switchover.

## Scope, with DevSecOps included

Adding DevSecOps properly makes five days untenable. Three honest options,
in order of preference:

### Option A — six days (recommended)

| Day | Topic |
|---|---|
| 1 | Git, Linux, networking |
| 2 | Cloud + Terraform |
| 3 | Ansible + Docker (networks, volumes) |
| 4 | CI/CD + SonarQube + observability |
| **5** | **DevSecOps** — the full gate chain and the six vulnerabilities |
| 6 | Swarm + Kubernetes + Demo Day |

This is the version I would run. DevSecOps sits after CI/CD, because a security
gate only makes sense once they have built a pipeline for it to live in, and
before Kubernetes, so that Kyverno and signed images land as *the same idea
again* rather than new material.

### Option B — five days, DevSecOps woven in

Add 45–60 minutes of security to each day, using the per-day thread in
`docs/DEVSECOPS.md`. They will meet every concept and go hands-on with none of
them. Honest depth: GUIDED at best, DEMO in practice.

### Option C — five days, split Day 4

- **Day 4a** — CI/CD + security gates (both are "automated checks with the
  authority to stop a release" — one idea, not two)
- **Day 4b** — Observability, all four pillars, unhurried

Cuts the Swarm block to buy the time. Workable, and the weakest of the three.

**Whichever you pick, do not cut observability to fit security in.** Day 4 PM
teaches them how to find out what is wrong, and every other day assumes that
skill.

## What to tell the interns on Monday

> Five days does not make you a DevOps engineer. It makes you someone who has
> touched every layer once and knows what to go deep on. That is a genuinely
> valuable position to be in and I am not going to pretend it is more.

Say it in the kickoff. It sets an expectation you can actually meet, and it
means that on Friday they measure themselves against the real target rather
than against a promise nobody made honestly.

---

## Beyond the core — platform extensions

The five-day scope above is the *curriculum*. The repo also ships four capabilities
that sit **on top** of it — depth-3, go-further material, none of them on the
nineteen-skill target list, and each one measured rather than merely demoed:

| Extension | Domain | Where |
|---|---|---|
| AI SRE Incident Copilot | AIOps | `ai/incident-copilot/` |
| Auto-grader / challenge arena | interactive assessment | `grader/`, `challenges/` |
| LLMOps + AI-security lab | LLMOps · OWASP-LLM | `ai/support-agent/` |
| Infracost cost gate | FinOps | `.github/workflows/infracost.yml` |

They're where the platform points *past* the core rotation. See
[TRAINING.md](../TRAINING.md#-ai--platform-extensions).
