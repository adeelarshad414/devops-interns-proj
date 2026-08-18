# DevOps Intern Rotation 2026 — deliverables

Kickoff deck, six-day rotation, demo platform, and the answer key.

---

## What is here

| # | File | For | What it is |
|---|---|---|---|
| 1 | `01-AUDIT-devops-intern-deck-2025.md` | you | Slide-by-slide audit of last year's deck |
| 2 | `02-DESIGN-devops-intern-kickoff-2026.md` | you | Kickoff design, run sheet timed to the minute |
| 3 | `03-CHARTER-objective-milestones-tasks.md` | **you first** | **Objective, 24 checkpoint questions, 8 milestones, 16 targets, 57 tasks** |
| 4 | `04-COVERAGE-skills-matrix.md` | you | The scope decision. Twenty skills, six days, honest depth per skill |
| 5 | `05-CHEATSHEET-handout.md` | **interns, Day 1** | Commands and the diagnostic ladder. **No answers — safe to print** |
| 6 | the private solutions repo | **you only** | **Step-by-step for every task, chaos variant and checkpoint question** |
| 7 | `07-DEVSECOPS-guide.md` | you | Seven gates, six vulnerabilities, supply chain, secrets |
| 8 | `08-DAIG-README.md` | both | The platform README, with architecture and flow diagrams |
| 9 | `09-ARCHITECTURE.md` | you | Eighteen design decisions and the alternatives rejected |
| 10 | `10-REQUIREMENTS.md` | you | 28 functional, 45 non-functional, with traceability |
| 11 | `11-DEPLOYMENT.md` | both | Per-environment procedures and rollback |
| 12 | `12-COST-estimate.md` + `.py` | you | What it costs on each cloud. Computed, not asserted |
| — | `devops-kickoff-2026.pptx` | you | 38 slides, speaker notes on all of them. PDF alongside |
| — | `daig-demo-repo.zip` | both | The demo platform. 178 files |

**Read 3 first.** It is the one page to point at when someone asks what this is
for and how you will know it worked.

---

## The one thing to get right about handout order

I split the cheat sheet in two, deliberately:

- **`05-CHEATSHEET-handout.md`** — commands, the diagnostic ladder, PromQL/LogQL/
  TraceQL, and a "things that will bite you" table. **Print it for every intern
  on Day 1.** Every exercise still works with it open.
- **the private solutions repo** — worked answers to all 57 tasks, all
  three Day 1 chaos variants, all three Day 3 variants, both Day 4 defects, all
  six vulnerabilities, all nine Demo Day scenarios, and all 24 checkpoint
  questions.

**Handing out the solutions on Day 1 deletes the rotation.** An intern who reads
the answer to the crash loop has learned a fact; one who found it has learned a
method. Release each day's section after that day closes, and the whole file at
T+1 as revision material.

If you disagree, they are separate files — merge them.

---

## The objective, in one sentence

> By the end of six days, every intern can take a system they did not write, find
> out why it is broken using evidence rather than guesswork, fix it at the right
> layer, and stop the same failure recurring.

Four verbs: **diagnose → fix → prevent → explain.**

---

## Cost, short version

**About $5 per cloud for the whole rotation** — cloud is only needed on 2 of the
6 days.

| 20 interns, 6 days | AWS | GCP | Azure |
|---|---|---|---|
| Recommended | $5.33 | $4.31 | $8.83 |
| Left running all week | $29.35 | $25.11 | $29.20 |
| Forgotten 30 days | $2,196 | $1,870 | $1,780 |

**Set the budget alert at $45 / $35 / $55 before the first `terraform apply`.**
The dominant variable is not the cloud — it is whether anyone runs
`terraform destroy`.

---

## Push the repo

```bash
unzip daig-demo-repo.zip && cd daig
./scripts/init-repo.sh git@github.com:<you>/daig.git
git push -u origin main
```

It refuses to initialise if it finds `.env`, `vault/.init-keys.json`, or anything
shaped like a real credential. Then on the forge: protect `main`, require CI and a
CODEOWNERS review, enable secret scanning with push protection, add
`SONAR_TOKEN` and `SONAR_HOST_URL`, replace the handles in `.github/CODEOWNERS`.

---

## Run it

```bash
cp .env.example .env
make hooks && make check
make up && make seed && make smoke
make obs           # observability
make vault-up      # OpenBao: initialise, unseal, provision
make vault-app     # Daig with credentials from the vault
make scan          # security toolchain
make help          # everything else

python3 scripts/cost-model.py
```

---

## Seven decisions before Day 1

All seven are in `03-CHARTER` §2.3 with recommendations. The three that block
everything else:

1. **Six days or five.** Six, per `04-COVERAGE` Option A. The deck is built for it.
2. **Which cloud is hands-on.** Cost is near-identical, so pick whichever tkxel
   bills most hours on — unless Kubernetes is your only cloud use, in which case
   Azure wins on the free AKS control plane.
3. **Cloud sandbox with a spend cap.** Days 2 and 6 collapse into demos without
   it. On a bill this small an AWS support plan costs more than the
   infrastructure — use an existing organisational account.

---

## Six tasks before Day 1

These are `T0.1`–`T0.10` in the charter. The six that matter most:

1. **Half a day running the repo.** Nothing has been executed except the cost
   model. `VERIFICATION.md` names the likeliest first failure (OpenTelemetry
   package versions).
2. **`make broken`, then run it.** The kickoff hands-on at minute 23 depends on
   that image exiting 78 with a log naming `DATABASE_URL`.
3. **`make vault-up`.** The longest unexercised script in the repo.
4. **`./security/scan-all.sh`.** Triage the findings before interns see them. If
   Semgrep reports zero, the custom rules need fixing and Day 5 collapses.
5. **Verify the `[E]` rates** in `cost-model.py`, and set the budget alerts.
6. **Find a local outage for slide 5.** One Pakistani incident the room lived
   through. I deliberately did not invent one — presenting an unsourced figure to
   interns teaches the opposite of what this rotation is about. The cold open
   works on CrowdStrike alone.

---

## One correction to check

Slide 7 has your bio as I understood it: 20+ years, CNCF Kubestronaut, 30
engineers. Last year's said "10+ years" and omitted Kubestronaut entirely, which
undersold you by a decade.
