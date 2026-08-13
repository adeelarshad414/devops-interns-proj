# Design — DevOps Intern Kickoff 2026 + 5-Day Rotation

**Supersedes:** `01-AUDIT-devops-intern-deck-2025.md`
**Superseded in part by:** `daig/docs/COVERAGE.md` §"Scope, with DevSecOps included" — read that for the day-count decision
**Scope:** One 2-hour kickoff session, plus the roadmap for a 6-day hands-on rotation
**Revision:** 3 Aug 2026 — extended from 5 to 6 days to give DevSecOps a real day rather than a bullet. See `daig/docs/COVERAGE.md` for the scope reasoning and the 5-day fallback.
**Audience:** Fresh-graduate interns, mixed backgrounds, arriving from Dev / Cybersecurity / UI-UX / QA rotations
**Author:** Adeel Arshad, Head of DevOps & Cloud
**Status:** Design — awaiting approval before slide build (`03-BUILD.md`)

---

## 1. The reframe

Last year's deck tried to be a curriculum in 65 slides. This year the curriculum is the *week*. The kickoff has a different and much narrower job.

**The kickoff must do exactly five things:**

1. Make them care — establish that this field exists because systems fail expensively
2. Give them the map — four disciplines, distinguished by what each does to the *same* system
3. Get their hands dirty once, early, before they've been talked at for an hour
4. Make each of the five days feel necessary rather than arbitrary
5. Set the stakes for Friday

**What the kickoff must NOT do:** teach tools. Every tool on the list — Terraform, Ansible, Docker, Kubernetes — gets a full day or half-day with a keyboard in front of them. Naming forty tools on Monday morning is how last year's deck failed. On Monday, a tool is only mentioned when it is the answer to a problem they have just watched happen.

**Design constraint that drives everything:** 120 minutes, ~40 slides maximum, and no stretch longer than 8 minutes without the room doing something.

---

## 2. The spine — "Daig"

One fictional product carried through the kickoff and all five days. Every module is a chapter in the same story, so knowledge compounds instead of resetting.

> **Daig** — a food delivery platform. Customers order, restaurants accept, riders deliver. Three services, one database, one payment integration. Small enough to hold in your head on day one, real enough to break in interesting ways.

*(Daig — the large pot used for cooking at scale. Local, memorable, and the name does thematic work: it's the thing that has to serve everyone at once.)*

**Why a fictional product rather than tkxel client systems:** no confidentiality exposure, failures can be engineered freely, and every intern starts equal regardless of which account they might later join.

### 2.1 The central failure — the iftar spike

This is the design centrepiece and it replaces every Netflix example in the old deck.

Daig's traffic is flat all day. Then, in the forty minutes before iftar, the entire country orders dinner simultaneously. It is the most predictable, most brutal, least forgiving traffic pattern in Pakistani consumer tech — and it has a hard deadline no engineer can negotiate with. You cannot tell a fasting customer their order is delayed.

Everything teaches off this single event:

| Concept | How the iftar spike teaches it |
|---|---|
| Capacity planning | You know the spike is coming. Why are you still down? |
| Autoscaling and its lag | Scale-up takes 90 seconds. The spike takes 20. |
| SLOs and error budgets | 99.9% uptime is fine — unless the 0.1% is 18:45 |
| Load shedding | Which requests do you drop when you can't serve all of them? |
| Cost | Provisioning for peak means paying for peak 24 hours a day |
| Observability | Which of the three services is actually the bottleneck? |
| Incident response | The pager goes off at the worst possible moment, by definition |
| Blameless postmortem | Nobody caused this. The system did. |

No intern in this room has worked at Netflix. Every one of them has waited on a food order at iftar. This is the highest-leverage single decision in the redesign.

---

## 3. Cold open — the outage

**No title slide. No agenda. No "hello everyone."** The screen is dark, then:

> **19 July 2024.**
> Airports worldwide stop. Airlines ground fleets. Hospitals revert to paper. Banks, broadcasters, emergency lines — down.
> Roughly 8.5 million Windows machines dead on the same morning.

Let it sit. Then ask the room: *what happened?* They'll guess cyberattack — the room always does.

Then the reveal:

> Not a hacker. Not a breach. Not even really a bug in the product.
>
> A security vendor pushed a configuration update to every customer at once. No staged rollout. No canary. No blast-radius control.
>
> **It wasn't a coding failure. It was a shipping failure.**
>
> That distinction is the entire reason this rotation exists.

Then, and only then, the title slide.

**Why this one:** it is recent, globally known, visually vivid (they remember the airport queues), and the root cause is precisely the subject of the week — deployment practice, not code quality. No definition of DevOps lands as hard as an intern independently concluding *"so they should have rolled it out slowly."* They'll say it themselves, unprompted, if you give them thirty seconds.

> **FACT-CHECK GATE — verify before presenting.** The device count (~8.5M, Microsoft's estimate), the date, and any financial figures (Delta's publicly claimed ~$500M is the most-cited) should be confirmed against current sources on the day. Present only figures you can source out loud if challenged. If a figure can't be confirmed, drop it — the story works without any number except the date and "millions of machines."

**Local second beat (gap — needs your input):** one Pakistani outage the room lived through would be even stronger than CrowdStrike, because it converts the lesson from *"big companies far away"* to *"this happens here."* Candidates: a national portal collapse under deadline load, a bank app failure on salary day, a telco outage. I've deliberately not invented one — pick an incident you can describe accurately, and put it immediately after CrowdStrike as slide 4.

---

## 4. Run sheet — 120 minutes

Interaction points marked **[R]** (room does something). Nothing runs longer than 8 minutes without one.

| Time | Min | Block | Slides | Notes |
|---|---|---|---|---|
| 00:00 | 8 | **Cold open** — CrowdStrike, then local incident | 1–5 | Dark screen. Ask the room what happened. **[R]** |
| 00:08 | 7 | **Who's talking and why** — bio, Kubestronaut, mood check-in | 6–8 | Keep last year's emoji check-in mechanic. **[R]** |
| 00:15 | 8 | **Meet Daig** — architecture on one slide; *what could go wrong?* | 9–11 | Collect answers on whiteboard, keep them visible all session. **[R]** |
| 00:23 | 10 | **HANDS-ON #1 — the crash loop** | 12–13 | See §5. Laptops open. **[R]** |
| 00:33 | 7 | **Debrief → what DevOps actually is** | 14–16 | Definition arrives *after* they've done it, not before |
| 00:40 | 12 | **Three acts: Pre-Prod → Prod → Post-Prod** | 17–21 | The mental scaffold for the whole week |
| 00:52 | 8 | **The iftar spike** — capacity, SLO, error budget | 22–24 | First real numbers. Error budget maths live. **[R]** |
| **01:00** | **8** | **BREAK** | — | Non-negotiable at the 60-minute mark |
| 01:08 | 14 | **One incident, three responses** — DevOps / SRE / Platform | 25–29 | Replaces last year's comparison table. See §6 |
| 01:22 | 8 | **Cloud + the 2026 layer** — OTel, DORA, AI in the loop | 30–32 | See §7 |
| 01:30 | 4 | **Myths, rapid-fire** | 33 | Live poll, one slide, 60 seconds. See §8 |
| 01:34 | 12 | **The week ahead** — Day 1–6 | 34–40 | See §9. Two minutes per day. |
| 01:46 | 5 | **Demo Day** — and how you're assessed | 41 | Stakes |
| 01:51 | 7 | **Q&A** | — | |
| 01:58 | 2 | **Close** — "Scope aap main hai, field mein nahi" | 41 | Earned now, unlike last year at minute 8 |

**Total: 38 slides, 120 minutes.** Down from 65 slides for the same slot. Slide count fell 42%; interaction points went from 1 to 6.

**Overrun protocol:** if you're behind at the break, cut §7 (Cloud + 2026 layer) to a single slide and reclaim 6 minutes. Never cut the hands-on and never cut the week walkthrough — those are the two blocks the session exists for.

---

## 5. Hands-on #1 — the crash loop (10 minutes, minute 23)

The single most important design decision in the kickoff: **they touch a terminal before they've heard a definition.**

**The exercise.** Every intern runs one command. Daig's order service starts, dies, restarts, dies again. They must work out why using only logs and exit codes.

```
docker run --name daig-orders tkxel/daig-orders:broken
```

The container exits immediately. The room's first instinct is always to run it again. It fails again. Then someone reads the logs.

**Engineered root cause:** a missing environment variable for the database connection string. Deliberately chosen because it is (a) the most common real-world container failure, (b) diagnosable in under five minutes by a total beginner, (c) fixable with one flag, and (d) a perfect setup for the config-management and secrets conversation on Day 3.

**The arc:**
- Minutes 0–3: everyone fails, nobody knows why, mild panic
- Minutes 3–6: someone reads the logs out loud, room converges
- Minutes 6–8: they add `-e DATABASE_URL=...` and it starts
- Minutes 8–10: debrief

**Debrief script — the payload of the whole session:**

> You just did four things.
> You **observed** — you read logs instead of guessing.
> You **formed a hypothesis** — the app can't reach its database.
> You **changed the configuration**, not the code.
> You **verified** the fix.
>
> That loop, at scale, with automation and other people's money on the line, is the job. Everything this week is that loop, larger.

**Prep requirement:** Docker Desktop installed and the image pulled *before* Monday. Send instructions the previous Thursday with a one-line verification command. Assume 20% arrive unprepared — pair them with someone who is prepared, which is itself a DevOps lesson.

**Fallback if the lab is unavailable or the room's laptops fail:** run it instructor-driven, but the room dictates every command. You type nothing they didn't say out loud. Weaker than hands-on, but far better than a demo they watch passively.

---

## 6. One incident, three responses (14 minutes, minute 68)

This block replaces slide 37 of the old deck — a single comparison table for the most confusing topic in the entire field. Interns consistently leave intro programmes unable to distinguish these four disciplines because they are always taught as three definitions side by side.

**Fix: one event, narrated four times.** Same incident, four people, four different questions.

> **18:42. Iftar in eighteen minutes. Daig's order service starts returning 503s. The pager fires.**

| Role | The question they ask | What they do in the next 10 minutes |
|---|---|---|
| **DevOps engineer** | *How do we get this shipped and running again?* | Rolls back the 17:30 deploy, confirms recovery, checks the pipeline for what got through |
| **SRE** | *How much failure can we afford before we stop shipping?* | Checks the error budget. It's 60% consumed with 11 days left in the window. Calls a change freeze. |
| **Platform engineer** | *Why was it possible to deploy this at 17:30 on a Thursday at all?* | Ships a deployment-window guardrail into the golden path so no team can do this again |
| **Cloud/FinOps** | *We survived by tripling the instance count. What did that cost, and can we afford it every night?* | Prices the spike, models the tradeoff between pre-provisioning and blowing the budget |

**The line to land:**

> Same incident. Four questions. **DevOps fixes today. SRE decides what "good enough" means. Platform makes the problem structurally impossible. Cloud/FinOps asks what it costs.**
>
> You'll do all four this week. In your career, you'll specialise into one — and you don't have to pick yet.

That last clause matters more than it looks. This audience is anxious about choosing wrong. Explicitly telling them the choice isn't due now buys real goodwill.

**Content that must be inside this block** (all missing from last year's deck entirely):
- **SLI / SLO / error budget** — defined here, in context, with the live arithmetic. This is SRE's core idea and it was absent from all 65 slides last year.
- **Golden path** and **self-service** — Platform Engineering's actual vocabulary.
- **Blast radius** — callback to the cold open.

**Live arithmetic to do on screen** (this is the moment the room goes quiet and starts thinking):

> 99.9% uptime over 30 days = **43 minutes** of allowed downtime per month.
> Tonight's incident: **14 minutes**.
> One incident spent a third of the month's budget.
> Three more like it and you stop shipping features until the window resets.

Interns have never seen reliability expressed as a spendable quantity. It reframes uptime from a vague virtue into a budget, which is the single most useful mental model in SRE.

---

## 7. Cloud and the 2026 layer (8 minutes, minute 82)

Deliberately compressed. This block exists to signal that the field has moved, not to teach any of it.

**Cloud (3 min).** Not a service catalogue. One idea: *the cloud is someone else's computer, rented by the second, and the bill is a design decision.* Show Daig's actual monthly cost broken down. Show what the iftar spike does to it. Given your FinOps and cost-intelligence background, a real (sanitised) bill on screen would be the most memorable slide in the session — nobody shows interns a bill.

**Observability (2 min).** Four pillars — logs, metrics, traces, profiles — introduced as *four different questions about the same request*, not four tool categories:

- **Logs** — what happened?
- **Metrics** — how often, how bad, trending which way?
- **Traces** — where in the chain of services did it go wrong?
- **Profiles** — which line of code is burning the CPU?

Name **OpenTelemetry** once as the standard that unified them. Do not tool-list. Day 4 is the day.

**AI in the loop (3 min).** Absent from last year's deck entirely; the largest currency gap for a 2026 cohort. Three points, no more:

1. AI-assisted incident triage and postmortem drafting is now normal practice, not novelty
2. Agentic remediation is arriving — and *who approves an agent's production change* is an unsolved problem they will be paid to think about
3. **The rotation rule, stated plainly:** *Use every AI tool you want. You must be able to explain every line you ship. If you can't explain it, you didn't write it, and it doesn't go to production.*

That third point does more for credibility with this cohort than any other sentence in the deck. They will use AI regardless; pretending otherwise marks you as out of touch, and banning it marks you as unserious. Setting a professional standard instead treats them like engineers.

---

## 8. Myths — rapid-fire (4 minutes, minute 90)

Last year: ten near-identical text slides in the session's dead zone. This year: **one slide, live poll, sixty seconds.**

Five statements. Hands up for true. Reveal all five are false. Ten seconds of correction each.

1. *DevOps means CI/CD* — no; CI/CD is a practice, DevOps is how the team is organised around it
2. *DevOps means no more ops team* — no; in mature orgs, developers join the on-call rotation, which is the opposite of removing ops
3. *DevOps is about tools* — no; wrong tools fix nothing if the process is wrong
4. *Automating everything removes bottlenecks* — no; it relocates them
5. *We should do what Netflix does* — no; Netflix's constraints are not yours, and copying their answers without their problems is cargo cult

Four minutes replaces twenty. The content survives; the format doesn't.

---

## 9. The week ahead (12 minutes, minute 94)

Each day gets one slide with an identical four-part structure, so the pattern becomes predictable and the week feels designed rather than assembled:

> **The Daig chapter** — what happens to our system today
> **You will build** — the concrete artifact, in their hands by 17:00
> **Chaos Hour** — what breaks at 16:00 and what you'll need to fix it
> **Without this** — what fails downstream if you skip today

### Day 1 — Foundations: Linux & Networking
- **Daig chapter:** Before Daig runs anywhere, it runs on a machine, and that machine talks to other machines.
- **Build:** SSH into a fresh VM, find a process eating CPU, kill it, trace why a service can't reach the database, read `ss`/`netstat` output, follow a request through DNS → TCP → HTTP.
- **Chaos Hour:** The order service can't reach the database. Firewall rule, wrong port, or DNS? Find out. Three planted causes, three teams.
- **Without this:** Every later problem looks like magic. 80% of "Kubernetes problems" on Friday are Linux and networking problems wearing a costume.

### Day 2 — Cloud & Infrastructure as Code (Terraform)
- **Daig chapter:** Daig needs somewhere to live. Click it into existence once, then never again.
- **Build:** Provision Daig's infra by hand in the console (deliberately — feel the pain), then destroy it and rebuild the same thing in Terraform. Run `plan`, read the diff, `apply`, then change one variable and watch the plan.
- **Chaos Hour:** Someone changed a resource in the console. Terraform state and reality disagree. Reconcile it.
- **Without this:** Infrastructure nobody can reproduce, nobody can review, and nobody can rebuild after it's deleted.
- **Deliberate sequencing:** console first, IaC second. Doing it by hand first is what makes IaC feel like relief rather than homework.

### Day 3 — Configuration Management (Ansible) & Containers (Docker)
- **Daig chapter:** The box exists. Now make it useful — then make the box irrelevant.
- **Build (AM):** Ansible playbook to configure the VM. Run it twice; discover idempotency by observing it.
- **Build (PM):** Containerise a Daig service. Write the Dockerfile, build, run, shrink the image, `docker compose up` the full stack.
- **Chaos Hour:** Callback to Monday — the crash loop returns, this time with three possible causes. They now have the vocabulary to name what they did on day one.
- **Without this:** "Works on my machine," forever.
- **Honest framing to give them:** Ansible is taught because you *will* meet it in existing systems, and because config management is a concept that outlives its tools. Also tell them Chef and Puppet are legacy in 2026 — they'll see the names and should know where they sit.

### Day 4 — CI/CD & Observability
- **Daig chapter:** Ship it automatically. Then see what you shipped.
- **Build (AM):** A pipeline that tests, builds, and deploys Daig on push. Then break the build on purpose and watch it refuse to deploy — the CrowdStrike lesson, made personal.
- **Build (PM):** Instrument a Daig service with OpenTelemetry. Generate load. Find the slow endpoint using a trace. Find the hot function using a profile. All four pillars, one request.
- **Chaos Hour:** Daig is slow at iftar. Nobody tells you which service. Find it in the traces.
- **Without this:** You ship blind and debug by guessing.
- **Load-risk note:** this is the heaviest day. De-scope lever: give them a pre-built pipeline and have them add one stage, rather than authoring from scratch.

### Day 5 — DevSecOps
- **Daig chapter:** Six real vulnerabilities are live in Daig right now. Find them before somebody else does.
- **Build:** Run the full gate chain (secrets, SAST, SCA, IaC, image, DAST). Triage the findings. Fix three properly. Then write a gate — a Semgrep rule, an OPA policy, or a test — so the fix cannot regress.
- **Chaos Hour:** Five of the six vulnerabilities get flagged automatically. One does not. Find it, and work out why no tool could have.
- **Without this:** You ship other people's vulnerabilities and find out from someone who is not on your side.
- **The line that carries the day:** tools find classes of bug; humans find missing rules. The unflagged vulnerability is a broken authorisation check — parameterised SQL, nothing unsafe, nothing any scanner can point at, and a missing business rule at the centre of it.
- **Full detail:** `daig/docs/DEVSECOPS.md`

### Day 6 — Kubernetes & Demo Day
- **Daig chapter:** One container is easy. Forty containers that must find each other, restart themselves, and survive a node dying — that's orchestration.
- **Build (AM):** Deploy Daig to a cluster. Pods, deployments, services, configmaps. Scale it. Delete a pod and watch it come back. Trigger a rolling update, then roll it back.
- **PM:** Demo Day.
- **Without this:** You can run software. You can't run software at scale.
- **Scope discipline:** deploy, scale, self-heal, roll back. Nothing else. No operators, no service mesh, no CRDs, no Helm charts they author themselves. One day buys four concepts, not a certification. Say this out loud so nobody leaves thinking they know Kubernetes.

### The through-line to state explicitly on Monday

> Monday you fix one container by hand.
> Friday, forty containers fix themselves.
> Everything in between is the story of how automation replaced you doing it manually — and why that's a promotion, not a threat.

---

## 10. Friday — Demo Day (5 minutes, minute 106)

Stakes. Last year's programme had none, which is the deeper reason nothing stuck.

**The format.** Each intern (or pair) owns a Daig deployment in their own namespace. In front of the room, you break it. They have ten minutes to diagnose and fix it, narrating as they go.

**Scored on four things, published Monday so they can aim at it:**

| Criterion | Weight | What it measures |
|---|---|---|
| Diagnosis method | 40% | Did they read logs, metrics, and traces — or guess and restart things? |
| Fix | 30% | Does it work, and is it the right layer to fix it at? |
| Narration | 20% | Can they explain it to a non-engineer? This is the job at senior level. |
| Recovery under pressure | 10% | Composure when the first hypothesis is wrong |

**Deliberate design note:** diagnosis is weighted higher than the fix. This is the message — *we are hiring for how you think, not what you memorised.* State that out loud. It converts Friday from an exam that punishes gaps into a chance to demonstrate reasoning, which is both truer to the job and considerably less terrifying.

**Failure is survivable and should be said so.** Some will not fix it in ten minutes. Tell the room on Monday that a well-reasoned failed diagnosis scores above a lucky guess. Otherwise Friday produces panic instead of thinking.

---

## 11. What changed, measured

| Dimension | 2025 | 2026 design |
|---|---|---|
| Slides | 65 | 38 |
| Session length | Unclear | 120 min, timed to the minute |
| Interaction points | 1 | 6 |
| Time to first hands-on | Never | 23 minutes |
| Analogies | 5 unrelated | 1 spine, carried 5 days |
| Real incidents | 0 | 2 sourced + 1 engineered per day |
| DevSecOps | Absent (one tool named) | A full day: 7 gates, 6 vulnerabilities, supply chain |
| Duplicate slides | 6 | 0 |
| Myth slides | 10 | 1 |
| Speaker notes | 0 of 65 | 38 of 38 |
| SLO / error budget | Absent | Core of the SRE block |
| DORA metrics | Absent | Introduced Day 4 |
| OpenTelemetry | Absent | Day 4 AM |
| AI in the lifecycle | Absent | Dedicated block + standing rotation rule |
| Assessment | None | Published rubric + Demo Day |
| Deliverable per intern | None | Running service, defended live |

---

## 12. Assumptions made in the absence of answers

Flagged per your evidence-over-assertion rule. Each is a decision I made to keep the design moving; each is cheap to reverse now and expensive to reverse after the build.

| # | Assumption | Impact if wrong |
|---|---|---|
| A1 | Interns have laptops with Docker installable, and admin rights | **High** — kills hands-on #1. Fallback in §5, but the session loses its best moment |
| A2 | A cloud sandbox with a spend cap exists for Days 2–5 | **Critical** — without it, Days 2 and 5 become demos and the rotation stops being hands-on |
| A3 | Cohort size 15–25 | Medium — above 30, Demo Day needs heats or parallel rooms |
| A4 | Interns have seen a terminal but are not comfortable in one | Medium — Day 1 pacing is built on this |
| A5 | tkxel template is mandatory | Low — affects visual design only |
| A6 | Confidentiality notice can move to an appendix slide | Low |
| A7 | Same instructor all five days | Medium — if not, speaker notes go from important to load-bearing |
| A8 | A local Pakistani outage exists that you can describe accurately | Medium — cold open works without it, but is meaningfully weaker |

---

## 13. Blocking items before `03-BUILD.md`

Only three genuinely block the slide build:

1. **A2 — cloud sandbox.** Confirm or deny. Everything from Day 2 onward is shaped by the answer, and the kickoff's Day 2–5 slides make promises the week must keep.
2. **The `tkxel/daig-orders:broken` image.** Needs building before Monday. Trivial work — a service that exits non-zero on a missing env var — but it must exist for the hands-on, and someone has to own it. Roughly an hour.
3. **A8 — the local incident.** Give me one you can describe accurately and I'll write the slide.

**Status: built.** `devops-kickoff-2026.pptx` — 38 slides, speaker notes on every one, validated with zero text-fit warnings and zero overlaps. The demo repository is `daig-demo-repo.zip` (141 files); read its `VERIFICATION.md` before trusting any of it.
