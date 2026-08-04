# DevOps Intern Rotation 2026 — deliverables

Everything for the 2-hour kickoff and the six-day hands-on rotation.

---

## What is here

| # | File | What it is |
|---|---|---|
| 1 | `01-AUDIT-devops-intern-deck-2025.md` | Slide-by-slide audit of last year's 65-slide deck. Verdict, defect register, what to keep. |
| 2 | `02-DESIGN-devops-intern-kickoff-2026.md` | Design for the kickoff and the rotation. Run sheet timed to the minute. |
| 3 | `03-COVERAGE-skills-matrix.md` | **The scope decision.** Twenty skills, six days, an honest depth level for each. |
| 4 | `04-DEVSECOPS-guide.md` | Seven gates, six vulnerabilities, supply chain, secrets. |
| 5 | `05-DAIG-README.md` | The demo platform's README, with architecture and flow diagrams. |
| 6 | `06-ARCHITECTURE.md` | Eighteen design decisions and the alternatives rejected. |
| 7 | `07-REQUIREMENTS.md` | 28 functional and 45 non-functional requirements, with IDs and traceability. |
| 8 | `08-DEPLOYMENT.md` | Environment-by-environment procedures and rollback. |
| — | `devops-kickoff-2026.pptx` | The deck. 38 slides, speaker notes on all of them. PDF alongside. |
| — | `daig-demo-repo.zip` | The demo repository. 173 files. `.tar.gz` alternative included. |

Read 3 first if you are planning. Read 5 first if you are running the code.

---

## Push the repo

```bash
unzip daig-demo-repo.zip && cd daig
./scripts/init-repo.sh git@github.com:<you>/daig.git
git push -u origin main
```

`init-repo.sh` refuses to initialise if it finds `.env`,
`vault/.init-keys.json`, or anything shaped like a real credential — the first
commit is the one people are least careful about, and Git history is forever.

Then on the forge:

- Protect `main`: require a PR, require CI, require a CODEOWNERS review
- Enable secret scanning **with push protection**
- Add repository secrets: `SONAR_TOKEN`, `SONAR_HOST_URL`
- Replace the placeholder handles in `.github/CODEOWNERS`

---

## Run it

```bash
cp .env.example .env
make hooks        # install the pre-commit hook
make check        # static checks, no Docker needed
make up && make seed && make smoke
make obs          # observability
make vault-up     # OpenBao: initialise, unseal, provision
make vault-app    # run Daig with credentials from the vault
make help         # everything else
```

---

## Three decisions still yours

1. **Six days or five.** `03-COVERAGE` gives three options; Option A (six days,
   DevSecOps as Day 5) is the one I would run. The deck is built for six.
2. **Which cloud is hands-on.** One applied properly beats three clicked
   through. Pick whichever tkxel bills the most hours on.
3. **Cloud sandbox with a spend cap.** Days 2 and 6 collapse into demos without
   it. Set the budget alert before the first `terraform apply`, not after.

---

## Five things to do before Day 1

1. **Half a day running the repo.** Nothing has been executed. Every file is
   syntax-checked; none is verified. `VERIFICATION.md` states which is which and
   names the likeliest first failure (OpenTelemetry package versions).
2. **`make broken`, then run it.** The kickoff hands-on at minute 23 depends on
   that image exiting 78 with a log naming `DATABASE_URL`.
3. **`make vault-up`.** `bootstrap.sh` is the longest unexercised script in the
   repo — init, unseal, policies, AppRole, verification login. Expect a CLI flag
   or two to differ.
4. **`./security/scan-all.sh`.** Triage the real findings before interns see
   them. If Semgrep reports zero, the custom rules need fixing and the DevSecOps
   exercise collapses.
5. **Find a local outage for slide 5.** One Pakistani incident the room lived
   through. I deliberately did not invent one — presenting an unsourced figure to
   interns teaches the opposite of what this rotation is about. The cold open
   works on CrowdStrike alone if nothing suitable comes to mind.

---

## One correction to check

Slide 7 has your bio as I understood it: 20+ years, CNCF Kubestronaut, 30
engineers. Last year's deck said "10+ years" and omitted Kubestronaut entirely,
which undersold you by a decade. Confirm the numbers.
