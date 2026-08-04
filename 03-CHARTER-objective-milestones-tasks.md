# Programme charter — DevOps Intern Rotation 2026

The single page to point at when someone asks what this rotation is for, how you
will know it worked, and what everyone is supposed to be doing.

---

## 1. Overall objective

> **By the end of six days, every intern can take a system they did not write,
> find out why it is broken using evidence rather than guesswork, fix it at the
> right layer, and stop the same failure recurring.**

Four verbs, in order: **diagnose → fix → prevent → explain.** Everything in the
rotation serves one of them.

### What this objective deliberately is not

| Not the objective | Why not |
|---|---|
| "Learn Docker, Kubernetes, Terraform and Ansible" | Tools are the vehicle. An intern who can drive four tools but cannot diagnose a failure is not employable as a DevOps engineer. |
| "Become a DevOps engineer" | Six days cannot do that, and promising it means Friday measures them against a target nobody honestly set. |
| "Get certified" | Certification tests recall. This tests judgement. |
| "Build a portfolio project" | They will build one, but as a by-product. The deliverable is the reasoning, not the artifact. |

### The sentence to say out loud on Day 1

> Six days does not make you a DevOps engineer. It makes you someone who has
> touched every layer once and knows what to go deep on. That is a genuinely
> valuable position to be in and I am not going to pretend it is more.

Setting an expectation you can actually meet is worth more than an inspiring one
you cannot.

---

## 2. The questions

### 2.1 The six questions the rotation exists to answer

Every intern should be able to answer all six, in their own words, by Friday.

| # | Question | Answered on |
|---|---|---|
| **Q1** | What problem does DevOps actually solve, and what happens without it? | Kickoff, Day 1 |
| **Q2** | How do DevOps, SRE, Platform Engineering and Cloud/FinOps differ, given they all touch the same system? | Kickoff |
| **Q3** | When something breaks, how do I find out why — without guessing? | Days 1, 4, 6 |
| **Q4** | How do I know whether a system is reliable *enough*? | Kickoff, Day 4 |
| **Q5** | How does code get from a laptop to production safely, and what stops a bad change? | Days 4, 5 |
| **Q6** | Where do credentials actually live, and how do I not be the reason they leak? | Day 5 |

**Q2 is the one every intro programme fails.** It is answered by narrating one
incident four times — same 503s at 18:42, four people, four different questions —
rather than by a comparison table nobody reads.

### 2.2 Checkpoint questions — asked at the end of each day

Not a written test. Asked out loud, to the room, in five minutes. If most of the
room cannot answer, the day did not land and tomorrow needs adjusting.

**Day 1 — Git, Linux, networking**
1. A service cannot reach its database. Name four different layers where that
   could break, and the command you would use at each.
2. `nc -zv host 5432` hangs versus returns "connection refused". What does each
   tell you?
3. You need to find which commit introduced a bug, and there are 200 commits
   since it worked. What do you do?
4. What does `git reflog` protect you from?

**Day 2 — Cloud and Terraform**
5. Before you run `terraform apply`, what is the one question you must ask about
   the plan?
6. Someone changed a resource in the console. Name the three possible correct
   responses and when each applies.
7. Why does this repository provision one NAT gateway rather than three?
8. What is still costing money after you close the console tab?

**Day 3 — Ansible and Docker**
9. You ran the playbook twice. Why did the second run report "ok" rather than
   "changed"?
10. `docker compose down` versus `docker compose down -v`. Which one did you
    regret?
11. Why does `localhost` inside a container not mean what you expect?
12. What problem do containers solve that configuration management cannot?

**Day 4 — CI/CD and observability**
13. Which of the four pillars tells you *where* in a chain a request slowed down?
    Which tells you *which line of code*?
14. Your SLO is 99.9% over 30 days. How many minutes of failure is that? You just
    had a 14-minute incident — now what?
15. What is the most valuable thing a pipeline does?
16. Why is adding an order id as a metric label a bad idea?

**Day 5 — DevSecOps**
17. Five of the six vulnerabilities were found by a scanner. Why not the sixth?
18. Where should a database password live, and why not in an environment
    variable?
19. What does a one-hour credential TTL do to an attacker who steals it at 09:00
    and uses it at 14:00?
20. You fixed a vulnerability. What must you do next so it does not come back?

**Day 6 — Kubernetes and Demo Day**
21. A pod is `Running` but not `Ready`. What is the difference, and where do you
    look?
22. You deployed a broken image and the rollout stalled instead of completing.
    Which two settings did that?
23. `kubectl get endpoints` returns nothing. What does that tell you?
24. Why does liveness not check the database when readiness does?

### 2.3 Open questions for the programme owner

Decisions that must be made before Day 1. Every one changes what the interns
actually do.

| # | Question | Recommendation | Status |
|---|---|---|---|
| **O1** | Six days or five? | Six. `docs/COVERAGE.md` Option A. | **open** |
| **O2** | Which cloud is hands-on? | Whichever tkxel bills most hours on. Cost is near-identical. | **open** |
| **O3** | Cloud sandbox with a spend cap? | Required. Without it Days 2 and 6 become demos. | **open** |
| **O4** | Do interns have laptops with Docker and admin rights? | Verify by Thursday before. Pair anyone who does not. | **open** |
| **O5** | Which local outage anchors the cold open? | Must be sourceable out loud. Cut the slide if not. | **open** |
| **O6** | Is Demo Day scored for the record, or formative only? | Formative. Say so, or Friday produces panic instead of thinking. | **open** |
| **O7** | Who else can deliver this if you are unavailable? | Speaker notes exist on all 38 slides for exactly this. | **open** |

---

## 3. Milestones

| ID | Milestone | Definition of done | When |
|---|---|---|---|
| **M0** | Programme ready | Repo runs end to end; `VERIFICATION.md` has real rows; budget alerts set; cohort confirmed | T-5 days |
| **M1** | Room engaged | Kickoff delivered; every intern has broken and fixed a container | Kickoff, minute 33 |
| **M2** | Foundations | Every intern has diagnosed a network fault and written it up | End of Day 1 |
| **M3** | Reproducible infrastructure | Every intern has applied, drifted, reconciled and destroyed a stack | End of Day 2 |
| **M4** | Immutable delivery | Every intern has built an image and run the full stack locally | End of Day 3 |
| **M5** | Evidence over guessing | Every intern has found a latency defect using traces and profiles, with before/after numbers | End of Day 4 |
| **M6** | Security as a gate | Every intern has triaged scanner output, found the unflagged vulnerability, and written a gate | End of Day 5 |
| **M7** | Diagnosis under pressure | Every intern has diagnosed a live failure in front of the room | End of Day 6 |
| **M8** | Programme improved | Retro captured; `docs/INSTRUCTOR.md` and day docs updated for next cohort | T+3 days |

**M8 is the one that gets skipped and the one that compounds.** Last year's deck
had zero speaker notes, so nothing carried forward and the programme started from
scratch. Do not repeat that.

---

## 4. Targets

Measurable, with a pass threshold. If a target is missed, the programme needs
changing — not the interns.

### 4.1 Intern-level targets

| ID | Target | Measure | Pass |
|---|---|---|---|
| **IT-1** | Can diagnose an unfamiliar failure | Demo Day: reads logs, metrics or traces before changing anything | ≥ 85% of interns |
| **IT-2** | Diagnoses by evidence, not by restarting | Demo Day: no blind restart as a first action | ≥ 80% |
| **IT-3** | Fixes at the correct layer | Demo Day: fix addresses cause, not symptom | ≥ 70% |
| **IT-4** | Can explain a technical failure to a non-engineer | Demo Day narration, 2 minutes, no jargon | ≥ 75% |
| **IT-5** | Can distinguish the four disciplines | Checkpoint Q2, in their own words | ≥ 90% |
| **IT-6** | Can state a reliability target as a budget | Checkpoint Q14: 99.9% → 43 min/month | ≥ 85% |
| **IT-7** | Produces one written diagnosis per day | 6 write-ups submitted | ≥ 90% of write-ups |
| **IT-8** | Knows what they do not know | Exit survey names 2 areas to go deeper on | 100% |

**IT-8 is not filler.** An intern who leaves knowing precisely what to learn next
is a better outcome than one who leaves believing they know Kubernetes.

### 4.2 Programme-level targets

| ID | Target | Measure | Pass |
|---|---|---|---|
| **PT-1** | Time to first hands-on | Stopwatch from session start | ≤ 25 min |
| **PT-2** | Interaction density | No stretch of one-way delivery | ≤ 8 min |
| **PT-3** | Every chaos hour runs | 6 of 6, not cut for time | 6/6 |
| **PT-4** | Cloud spend | Against `docs/COST.md` | ≤ budget alert |
| **PT-5** | Zero credentials leaked | gitleaks clean on every intern branch | 0 findings |
| **PT-6** | Zero orphaned cloud resources | Console empty 24h after Day 6 | 0 resources |
| **PT-7** | Deliverable per intern | A running service they can demo | 100% |
| **PT-8** | Transferability | Another engineer could deliver from the notes | Reviewer confirms |

---

## 5. Tasks

Task IDs are `T<day>.<n>`. Each has one deliverable. Commands are in
`docs/CHEATSHEET.md`; worked solutions in `docs/SOLUTIONS.md` (instructor-held
until the day closes).

### Pre-flight — T0

| ID | Task | Owner | Deliverable |
|---|---|---|---|
| **T0.1** | Run the stack end to end; fix OTel version drift | Instructor | `make smoke` green |
| **T0.2** | Build and publish `tkxel/daig-orders:broken`; confirm exit 78 | Instructor | Image in the registry |
| **T0.3** | Confirm a trace crosses all three services in Tempo | Instructor | Screenshot |
| **T0.4** | `terraform init && validate` on the chosen cloud | Instructor | Clean output |
| **T0.5** | `make vault-up`; confirm `credential_source: openbao` | Instructor | Log line |
| **T0.6** | `./security/scan-all.sh`; triage findings before interns see them | Instructor | Triage notes |
| **T0.7** | Set budget alerts per `docs/COST.md` | Instructor | Alert configured |
| **T0.8** | Send prep instructions: Docker, admin rights, laptop | Instructor | Email sent T-4 |
| **T0.9** | Source a local outage for the cold open, or cut slide 5 | Instructor | Slide finished |
| **T0.10** | Update `VERIFICATION.md` with real rows | Instructor | Rows moved |

### Day 1 — Git, Linux, networking

| ID | Task | Deliverable |
|---|---|---|
| **T1.1** | Clone, install the pre-commit hook, run `make check` | Green output |
| **T1.2** | Branch, stage with `git add -p`, commit conventionally, open a PR | Merged PR |
| **T1.3** | Create a merge conflict with a partner and resolve it by hand | Resolved conflict |
| **T1.4** | Find which commit introduced a change using `git log -S` and `bisect` | The SHA |
| **T1.5** | Recover "lost" work with `git reflog` | Recovered branch |
| **T1.6** | Inside a running container: find the busiest process, what is listening, disk use | Notes |
| **T1.7** | Follow one request through DNS → TCP → HTTP with four different tools | Four outputs |
| **T1.8** | **Chaos:** diagnose why orders cannot reach the database | **Written diagnosis** |
| **T1.9** | Compare diagnoses across teams — three symptoms, three causes | Comparison notes |

### Day 2 — Cloud and Terraform

| ID | Task | Deliverable |
|---|---|---|
| **T2.1** | Provision the stack by hand in the console. Deliberately. | Running stack |
| **T2.2** | Destroy it by hand. List what you forgot. | The list |
| **T2.3** | `terraform init`, read the plan line by line, `apply` | Applied stack |
| **T2.4** | Change `db_instance_class`; predict replace-or-modify before running `plan` | Prediction + plan |
| **T2.5** | Read `infra/gcp/` and `infra/azure/`; map three concepts to AWS equivalents | Mapping table |
| **T2.6** | **Chaos:** reconcile state against a console change | Decision + rationale |
| **T2.7** | Run `scripts/cost-model.py`; identify the largest line item and why | Annotated output |
| **T2.8** | `terraform destroy`; verify the console is empty | Empty console |

### Day 3 — Ansible, Docker, networks and volumes

| ID | Task | Deliverable |
|---|---|---|
| **T3.1** | Run the playbook twice; explain the difference | Explanation |
| **T3.2** | Add a task to the `common` role; keep it idempotent | Playbook diff |
| **T3.3** | Write a Dockerfile for a Daig service from scratch | Working image |
| **T3.4** | Shrink it — multi-stage, `--omit=dev`, alpine. Measure before and after. | Two sizes |
| **T3.5** | Change one source line, rebuild, identify which layers were reused | Build output |
| **T3.6** | Disconnect a container from its network; observe; reconnect | Notes |
| **T3.7** | Build three-tier isolation by hand with `--internal`; prove web cannot reach the DB | Failed connection |
| **T3.8** | Run `down` then `down -v`. Observe the difference. | The lesson |
| **T3.9** | Find one named volume, one bind mount, one tmpfs in this repo | Three references |
| **T3.10** | **Chaos:** distinguish config-missing from config-wrong from environment-wrong | Written diagnosis |

### Day 4 — CI/CD and observability

| ID | Task | Deliverable |
|---|---|---|
| **T4.1** | Read `ci.yml`; state what each of the four jobs catches | Four sentences |
| **T4.2** | Break a test on purpose; watch the pipeline refuse to deploy | Failed run URL |
| **T4.3** | Add one stage to the pipeline | Passing run |
| **T4.4** | Run a SonarQube scan; triage three findings as real or noise | Triage notes |
| **T4.5** | Bring up the observability stack; generate the iftar curve | Dashboard screenshot |
| **T4.6** | Compute the error budget from the dashboard; state minutes remaining | The number |
| **T4.7** | Find the slow endpoint using a trace, not by reading code | Trace screenshot |
| **T4.8** | Find the hot function using a profile | Flame graph screenshot |
| **T4.9** | **Chaos:** find both latency defects; fix; measure again | **p95 before/after** |
| **T4.10** | Try adding an order id metric label; observe series count; remove it | Series count |

### Day 5 — DevSecOps

| ID | Task | Deliverable |
|---|---|---|
| **T5.1** | Enable `INSECURE_MODE`; run the full toolchain | Scan reports |
| **T5.2** | Triage every finding: real, reachable, impact here | Triage table |
| **T5.3** | **Find the vulnerability no scanner reported.** Explain why it could not. | The answer |
| **T5.4** | Fix three vulnerabilities properly, not by uncommenting | Three diffs |
| **T5.5** | Write a Semgrep rule or OPA policy that prevents regression | Working rule |
| **T5.6** | Complete the stubbed rule `daig-direct-pool-query`; find where the repo breaks its own convention | Rule + location |
| **T5.7** | `make vault-up`; read the audit log; find your own secret access | Log line |
| **T5.8** | Prove least privilege: log in as `dispatch`, attempt a denied read | The denial |
| **T5.9** | Mint a dynamic database credential; state its TTL | Credential + TTL |
| **T5.10** | Sign an image, verify it, then verify something unsigned and watch it fail | Both outputs |

### Day 6 — Kubernetes and Demo Day

| ID | Task | Deliverable |
|---|---|---|
| **T6.1** | Deploy a Swarm stack; scale it; kill a task; observe recovery | Notes |
| **T6.2** | Roll a Swarm service forward, then to a broken image; watch auto-rollback | Output |
| **T6.3** | Map five Swarm concepts to Kubernetes equivalents | Mapping table |
| **T6.4** | `kubectl apply -k k8s/base`; narrate the pod state transitions | Four states named |
| **T6.5** | Scale to 5; confirm the Service load-balances with no config change | Endpoints output |
| **T6.6** | Delete a pod; time the recovery | The time |
| **T6.7** | Deploy a broken image; explain why the rollout stalls; roll back | Two settings named |
| **T6.8** | Find the two settings in `orders.yaml` that made it stall | The lines |
| **T6.9** | **Demo Day:** diagnose a live failure in front of the room | **Live diagnosis** |
| **T6.10** | Write the postmortem for your Demo Day scenario | Postmortem |

### Post-rotation — T7

| ID | Task | Owner | Deliverable |
|---|---|---|---|
| **T7.1** | Exit survey: two areas each intern wants to go deeper on | Instructor | Responses |
| **T7.2** | Score against targets in §4; record which were missed | Instructor | Scorecard |
| **T7.3** | Retro: where the room was lost, recurring questions | Instructor | Notes |
| **T7.4** | Update `docs/INSTRUCTOR.md` and day docs from the retro | Instructor | Committed diff |
| **T7.5** | Confirm zero orphaned cloud resources; reconcile the bill to `docs/COST.md` | Instructor | Console + invoice |
| **T7.6** | Release `docs/SOLUTIONS.md` to the interns | Instructor | Shared |

---

## 6. Traceability

| Target | Proven by |
|---|---|
| IT-1, IT-2, IT-3 | T6.9 Demo Day |
| IT-4 | T6.9 narration, T6.10 postmortem |
| IT-5 | Checkpoint Q2 |
| IT-6 | T4.6, Checkpoint Q14 |
| IT-7 | T1.8, T2.6, T3.10, T4.9, T5.3, T6.10 |
| IT-8 | T7.1 |
| PT-1, PT-2 | Kickoff run sheet |
| PT-3 | T1.8, T2.6, T3.10, T4.9, T5.1, T6.9 |
| PT-4 | T2.7, T7.5 |
| PT-5 | T5.1, pre-commit hook, CI gate |
| PT-6 | T2.8, T7.5 |
| PT-7 | T6.4–T6.8 |
| PT-8 | Speaker notes, T7.4 |

Every target has at least one task that proves it, and every task serves at least
one target. If either stops being true, one of them is decoration.
