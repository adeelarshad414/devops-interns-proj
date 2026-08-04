# Audit — `DevOps @ tkxel — Deep Dive — 25`

**Artifact:** `DevOps___tkxel_-_Deep_Dive_-_25.pptx` · 65 slides · 38 MB
**Audited:** 3 August 2026
**Purpose of audit:** Establish the baseline before the 2026 rebuild for Gen Z fresh-graduate interns across DevOps / Cloud / SRE / Platform Engineering.
**Method:** Full text extraction (`markitdown`), full visual render (65/65 slides inspected), speaker-notes inspection, currency check against 2026 practice.

---

## 0. Verdict

**The deck is a competent 2019 introduction to DevOps, delivered warmly, that is structurally broken, pedagogically passive, and roughly six years behind current practice.**

It has one genuine, rare strength — the Roman Urdu code-switching and the local analogies create real warmth, and warmth is the hardest thing to manufacture in technical training. That is worth preserving and should survive the rebuild intact.

Everything around that strength needs work. The deck teaches *vocabulary*, not *judgement*. An intern who sits through all 65 slides can define DevOps, SRE, and Platform Engineering, and can name roughly forty tools. They cannot deploy anything, cannot read a dashboard, have never seen a failure, and have no basis for deciding what to learn first.

**Disposition:** Rebuild, don't refactor. Approximately 30% of the content is salvageable as raw material; the architecture is not. A deck assembled by appending sections cannot be fixed by appending more.

| Verdict | Slide count | Share |
|---|---|---|
| **Keep** (works as-is or with light edit) | 8 | 12% |
| **Rewrite** (right idea, wrong execution) | 21 | 32% |
| **Cut** (redundant, broken, or off-mission) | 24 | 37% |
| **Cut and replace with something structurally different** | 12 | 19% |

---

## 1. Slide-by-slide inventory

| # | Content | Verdict | Note |
|---|---|---|---|
| 1 | Title — "DevOps @" | Rewrite | Title truncated; no cohort/date/version |
| 2 | Agenda | **Cut — critical defect** | Agenda is for an *Observability* talk, not this deck |
| 3 | "It's Monday… Again!" | Keep | Good opener energy |
| 4 | Emoji mood check-in | **Keep** | Best interaction in the deck; the only two-way moment |
| 5 | "Welcome Aboard Brave New Recruits" | Keep | Fine as a beat |
| 6 | Presenter bio | Rewrite | Stale — see §2.5 |
| 7 | Expectations for rotation | Rewrite | Aspirational, not measurable |
| 8 | Team stats (50+ total / 27 current / intern conversion) | **Rewrite — reads badly** | See §2.7 |
| 9 | "Work Hard, Party Harder" | Keep | Culture signal; effective |
| 10 | "There's more in you than you realize" | Cut | Unearned motivation at minute 8 |
| 11 | "Scope Aap Main Hai, Field Mein Nahi" | Keep | Strong line, genuinely good |
| 12 | Batman/Ra's al Ghul quote | Cut | Unearned; also third motivational slide in a row |
| 13 | "The DevOps Journey: Zero to Hero" | Rewrite | Section divider, no content |
| 14–22 | Last year's intern photos (9 slides) | **Cut → replace** | Nine consecutive uncaptioned photo slides. See §3.3 |
| 23 | "DevOps kya hai?" hook | Keep | Good transition |
| 24 | "Lekin ye DevOps hai Kya?" — definition | Rewrite | Definition-first; see §3.1 |
| 25 | What is DevOps? + Punjabi shaadi analogy | Rewrite | Analogy memorable, teaches org chart not engineering |
| 26 | Wall of Confusion / Myths intro | Cut | Announces myths 17 slides before the myths arrive |
| 27 | Fast-food restaurant analogy | Rewrite | Second unrelated analogy |
| 28 | DevOps in Action — crashing mobile app | **Rewrite → promote** | Closest thing to a real scenario; should become the spine |
| 29 | Why DevOps? (6 benefits + Netflix) | Cut | Duplicated at slide 53 |
| 30 | DevOps Lifecycle (infinity loop) | Rewrite | Image-only, no narration, no notes |
| 31 | DevOps Process Flow | Cut | Redundant with 30 |
| 32 | Why DevOps is the Future | Rewrite | Unsourced growth claim; "2024–2030" now stale |
| 33 | What is SRE? | Rewrite | **No mention of SLO, SLI, or error budget** — see §4.2 |
| 34 | SRE — cricket match analogy | Rewrite | Third unrelated analogy |
| 35 | What is Platform Engineering? | Rewrite | No golden paths, no cognitive load, no product framing |
| 36 | Platform Eng — shopping mall analogy | Rewrite | Fourth unrelated analogy |
| 37 | **DevOps vs SRE vs Platform Engineering** | **Rewrite — highest priority** | One image slide for the single most confusing topic |
| 38 | Why DevOps is Exciting | Cut | Generic; overlaps 29 and 32 |
| 39 | Specialized domains (GitOps→DevSecOps, 7 items) | Rewrite | Wall of text, 7 definitions, no hierarchy |
| 40 | How to Start Your Journey | Rewrite | Advice is sound but generic and undated |
| 41 | DevOps Roadmap (image) | Cut | Duplicate of 57 |
| 42 | Real-World Insights (Netflix/Spotify/Amazon/Google) | **Rewrite** | All four examples are 2010s canon — see §4.4 |
| 43–52 | Myths about DevOps (10 slides) | **Cut → compress** | Ten near-identical text slides. See §3.4 |
| 53 | Why DevOps? | Cut | Verbatim duplicate of 29 |
| 54 | Image-only slide | Cut | No text, no notes, unclear purpose |
| 55 | DevOps Culture (6 values) | Keep | Concise and correct |
| 56 | DevOps Principles (CAMS) | Keep | Correct; should move much earlier |
| 57 | DevOps Roadmap (image) | Rewrite | Roadmap image unreadable at presentation size |
| 58 | **Raw Google Sheets URL** | **Cut — defect** | An unformatted link is the entire slide |
| 59 | Domain list (13 domains) | Rewrite | Naked list, no sequencing |
| 60 | Cloud / Migration / CI-CD tools | Rewrite | 10 CI tools named, no guidance |
| 61 | IaC / Config Mgmt / Containers / Monitoring tools | Rewrite | "Cheff" typo; Chef & Puppet as if current |
| 62 | Security / GitOps / FinOps / Code Quality | Rewrite | ORCA as the only security tool |
| 63 | Q&A | Rewrite | Ends on a shrug |
| 64 | Contact | Rewrite | Personal Gmail exposed; unresolved editorial TODO in notes |
| 65 | Confidentiality Notice | Cut | Last thing an intern sees is a legal threat |

---

## 2. Hygiene defects — objectively wrong, fix regardless of redesign

These are not matters of taste. Each is a visible error.

**2.1 — The agenda belongs to a different deck.** Slide 2 lists: *What is Observability · Observability vs Monitoring · Why Observability Matters · Core Pillars of Observability · Demo of Observability.* This is an Observability talk's agenda sitting on slide 2 of an Intro-to-DevOps deck. Nothing that follows matches it. Anyone paying attention at minute 2 is confused, and the promised demo never arrives. Severity: **P0**.

**2.2 — Agenda numbering is broken.** Items 4 and 5 are both labelled `04`.

**2.3 — Slide numbering is broken throughout.** The number field shows `25` on nine consecutive slides (14–22), `47` on fifteen slides (42–56), `46 46` duplicated on slide 59, and stray `01` on slides 61–62. Elsewhere the literal placeholder `‹#›` renders unresolved. The deck was assembled by copy-paste and the field was never re-linked.

**2.4 — Copyright reads `© 2022`** on a 2025 deck, on both closing slides.

**2.5 — The presenter bio is materially understated and stale.** It reads "10+ years of experience" and "Cloud Solution Architect & HOD DevOps," with "10+ certifications." Current reality is 20+ years, Head of DevOps & Cloud, and CNCF Kubestronaut. The Kubestronaut credential in particular is the single most credible signal to this audience and it is absent — there are only a few thousand worldwide, and it is exactly the kind of concrete, verifiable achievement that buys authority with a sceptical room. Understating your own record by a decade is the one edit with a guaranteed positive return.

**2.6 — Personal Gmail address is on the contact slide** alongside the corporate address. Remove.

**2.7 — The team-stats slide reads as a warning.** It shows `3/10 Interns 2023-2024` and `1/25 Interns 2024-2025`. Read plainly, that is a conversion rate falling from 30% to 4%. Whatever the intended meaning, an incoming cohort will read it as *"almost none of you will be hired."* Either explain the denominator explicitly or remove the figures.

**2.8 — Slide 58 is a bare Google Sheets URL** as its entire content. Unclickable in presentation mode, meaningless in the exported PDF, and a dead link the moment the sheet's sharing changes.

**2.9 — An unresolved editorial note shipped in the file.** Slide 64's speaker notes contain: *"Under other offices all are mentioned city-wise except poland. Ideally it should be krakow then."* A reviewer's comment left in the deliverable.

**2.10 — Typo: "Cheff"** should be "Chef" (slide 61).

**2.11 — Speaker notes are empty on all 65 slides.** Not sparse — empty, apart from the stray editorial comment above. Three consequences: the deck cannot be delivered by anyone except you, there is no record of what was actually taught, and nothing can be improved between cohorts because nothing was captured. For a programme that runs annually and is meant to scale across a 30-person team, this is the most expensive defect in the file.

---

## 3. Structural findings

**3.1 — The deck teaches definitions, not consequences.** Nearly every content slide follows the shape *"X is …"* followed by a bulleted list of attributes. There is no point in 65 slides where an intern is shown something broken and asked what they would do. Curiosity requires a gap between what someone knows and what they want to know. Definitions close the gap before it opens.

**3.2 — Five unrelated analogies, none of which compound.** Punjabi shaadi (25) → fast-food restaurant (27) → cricket match (34) → shopping mall (36) → chai wala (35). Each is locally charming. Collectively they teach the same lesson five times — *these are different roles that must cooperate* — and none teaches anything about engineering. They explain the org chart. They also reset the audience's mental model at every switch, so nothing accumulates.

**3.3 — Nine consecutive slides of uncaptioned intern photographs (14–22).** This is roughly 14% of the deck. The photos are nostalgia for the presenter and the returning team; for a new cohort looking at strangers, they are dead air. The underlying instinct is correct — *people like you did this* is powerful social proof. But it only works with captions: name, what they built, where they are now. Uncaptioned, it is a slideshow of people the audience has never met.

**3.4 — Ten near-identical "Myths about DevOps" slides (43–52).** Same title, same layout, one paragraph each. Slides 43–52 are visually indistinguishable in the render. Myths are worth covering — several of these are genuinely the misconceptions grads arrive with — but ten sequential paragraph slides is the least engaging possible format for them, and they sit in the last third of a session where attention is already spent.

**3.5 — The running order was assembled, not designed.** The sequence runs: DevOps → SRE → Platform Engineering → *back to* DevOps myths → Why DevOps (repeated) → DevOps culture → DevOps principles → roadmap → schedule → domain lists → tool lists. Foundational material (CAMS principles, slide 56; culture, slide 55) appears at slide 55 of 65, after ten myth slides. Duplicates confirm append-only growth: "Why DevOps?" at 29 and 53, "DevOps Roadmap" at 41 and 57, myths announced at 26 and delivered at 43.

**3.6 — Nothing is hands-on. Nothing is assessed.** No lab, no live demo, no terminal, no exercise, no quiz, no checkpoint. The deck's own agenda promises a demo that does not exist. The session ends on Q&A → contact → legal notice. There is no mechanism by which you or the intern can know whether anything was learned.

**3.7 — The deck stops at deployment.** There is no pre-production / production / post-production spine. Monitoring appears as a tool category. Absent entirely: on-call, alert design, severity levels, incident command, escalation, blameless postmortems, toil budgets, capacity planning, cost review, decommissioning. This is where DevOps actually happens, and it is the part interns have literally never seen.

---

## 4. Currency — what is stale for 2026

**4.1 — Configuration management is presented as a live choice.** "Cheff, Puppet, Ansible" sits alongside Terraform as if these are peers a 2026 graduate should evaluate. Chef went to Progress Software in 2020, Puppet to Perforce in 2022; neither is where anyone starts today. Ansible remains relevant. Meanwhile OpenTofu, Pulumi, and Crossplane are absent.

**4.2 — The SRE section never mentions error budgets.** Slide 33 defines SRE as uptime monitoring, incident response, and automation. SLIs, SLOs, and error budgets — the actual conceptual core, the thing that makes SRE different from ops with a new name — do not appear anywhere in 65 slides. Neither do DORA's four keys (deployment frequency, lead time, change failure rate, time to restore). An intern leaves unable to answer *"how do you know if your system is reliable enough?"*, which is the entire question.

**4.3 — Observability is presented as 2016-era monitoring.** Slide 61 lists "Logging & Monitoring: NewRelic, Graylog, Prometheus, Grafana, DataDog, Prisma Cloud, Sentry." OpenTelemetry — now the default instrumentation standard and the second-largest CNCF project — appears nowhere. Neither do traces as a first-class pillar, continuous profiling, or eBPF. Given that you build an LGTM-stack observability platform, this gap is conspicuous.

**4.4 — All four "Real-World Insights" are 2010s canon.** Netflix Chaos Monkey (announced 2011), Spotify squads and tribes, Amazon two-pizza teams, Google SRE. Every intro-to-DevOps deck on the internet uses these four. Worse, the Spotify model is the weakest of them: engineers who were there have publicly described it as aspirational rather than something that actually worked at scale, and Spotify itself moved on. Teaching it as a model to emulate in 2026 is teaching a cautionary tale as a success story.

**4.5 — Platform Engineering is defined without its vocabulary.** No golden paths, no self-service, no platform-as-product, no developer cognitive load, no Team Topologies, no Backstage or equivalent IDP tooling, no platform maturity model. The section defines the term correctly and stops.

**4.6 — DevSecOps is one word and one tool.** Slide 62 lists "Security: ORCA." Absent: SBOM, SLSA, sigstore/cosign, supply-chain attacks as a threat model, secrets management, policy-as-code (OPA/Kyverno), and shift-left scanning in the pipeline. "Shift-left" is named on slide 39 and never explained.

**4.7 — AI in the delivery lifecycle is entirely absent.** Not one mention across 65 slides. For a cohort graduating in 2026 — who have used AI coding assistants throughout university and will use them from day one — this is the largest single gap in the deck. Missing: AI-assisted code review in CI, LLM-assisted incident triage and summarisation, agentic remediation, MCP and tool-calling in ops workflows, prompt/context engineering as a platform skill, and the governance questions that come with all of it. The deck's "Why DevOps is the Future" slide (32) predicts a future that has already arrived and doesn't mention it.

**4.8 — Kubernetes gets one line.** "Docker, Docker Swarm, Kubernetes / Istio, Helm" on slide 61. Docker Swarm is listed as a peer to Kubernetes. For a Kubestronaut-led programme this undersells both the topic and the instructor.

**4.9 — FinOps is framework-only.** The three phases (Inform, Optimize, Operate) are correct and current, but there is no unit economics, no cost-per-transaction, no showback/chargeback, no tagging discipline, no example of a real bill. Again — you build cost-intelligence platforms; a live bill would be the most memorable slide in the deck.

---

## 5. Engagement — reading the room

**5.1 — Time to first interaction: good. Time to second: never.** Slide 4's emoji mood check-in is the strongest engagement instinct in the deck and it lands in the first five minutes. Then approximately sixty slides pass with no further two-way moment until Q&A. The deck front-loads all of its interactivity into one slide.

**5.2 — Humour is carrying the load that stakes should carry.** The Roman Urdu asides are the best writing in the deck — *"Scope aap main hai, field mein nahi"* is a genuinely good line, and *"Remote sirf zaroorat padne pe"* is exactly the right register. But humour maintains attention; it does not create investment. *"Agar website band hui to SRE ki shamat ati hai"* is funny. It does not make anyone feel a pager going off at 3 a.m. The deck is likeable and low-stakes, and low stakes is why nothing sticks.

**5.3 — Three motivational slides in a row at minute 8** (10, 11, 12). Inspiration before the audience has any reason to be invested reads as a preamble to get through. The same three slides at the *end*, after they have broken and fixed something, would land completely differently.

**5.4 — The deck ends on a confidentiality notice.** Final beat of a first-day welcome session: Q&A, contact details, then a paragraph reserving the right to take action against violations. Whatever the legal requirement, it should not be the last thing a nervous 22-year-old reads on day one.

**5.5 — The audience assumption is off by a generation.** Emoji density, "Zero to Hero," and hero's-journey framing were current when this deck's ancestors were written. A 2026 fresh graduate's reference points are different, their tolerance for being marketed to is lower, and their detection of performed enthusiasm is close to instant. The Roman Urdu works because it is authentically yours. The emoji and the hero framing don't, because they aren't.

---

## 6. What to preserve

Explicitly, so it does not get lost in a rebuild:

1. **Roman Urdu code-switching.** Non-negotiable. It is the deck's real differentiator and no competitor programme has it.
2. **The mood check-in (slide 4)** — keep the mechanic, multiply it.
3. **"Scope aap main hai, field mein nahi"** — relocate to the close.
4. **"Work Hard, Party Harder" (slide 9)** — culture signal, effective.
5. **DevOps Culture (55) and CAMS Principles (56)** — correct content, wrong position; move to the front third.
6. **The crashing-mobile-app scenario (28)** — the only real scenario in the deck; promote it to the spine of the entire programme.
7. **The intern-photo instinct** — keep the idea, add captions and outcomes, cut from nine slides to one or two.
8. **The myths content** — several are the real misconceptions grads hold. Keep the substance, destroy the format.

---

## 7. Recommended rebuild architecture

Not a slide list — an architecture. Detail to follow in `02-DESIGN.md` once programme constraints are fixed.

**7.1 — One spine scenario for the entire programme.** A single fictional product, team, and codebase followed from first commit to incident to postmortem to cost review. Every domain becomes a chapter in one story rather than a standalone module. This is the single highest-leverage change: it makes DevOps, SRE, and Platform Engineering distinguishable by *what each one does to the same system*, which is the distinction interns currently leave without.

**7.2 — Cold open on a real, sourced outage.** Open with a public postmortem — real company, real date, real duration, real cost, real root cause. No definitions in the first ten minutes. Establish that this field exists because systems fail expensively, then earn the definitions.

**7.3 — Three-act structure: Pre-Production → Production → Post-Production.** This directly answers the brief and fixes §3.7. Pre-prod: plan, code, build, test, secure, package. Prod: release, deploy, progressive delivery, config, secrets, scale. Post-prod: observe, alert, on-call, incident, postmortem, cost, capacity, retire. The third act is where the current deck has nothing and where the actual job lives.

**7.4 — Hands-on within the first twenty minutes, then every session.** Break something on purpose and let them fix it. A deliberately failing pipeline they must diagnose is worth more than fifteen slides on CI/CD.

**7.5 — Domain differentiation as a worked example, not a comparison table.** One incident, narrated three times — how a DevOps engineer, an SRE, and a platform engineer each respond to it. Replaces slide 37 and is the clearest way to teach the distinction.

**7.6 — Modernise the canon.** Retire Chaos Monkey / Spotify squads / two-pizza teams as headline examples. Replace with recent, documented, sourced incidents and practices — and where possible, with **tkxel's own war stories**, which no competitor programme can copy and which are far more credible than Netflix to someone who will never work at Netflix.

**7.7 — Add the 2026 layer explicitly.** OpenTelemetry, DORA and SLO/error-budget thinking, platform-as-product and golden paths, supply-chain security, FinOps unit economics, and AI in the delivery lifecycle as a first-class section rather than a footnote.

**7.8 — Assessment and a demo day.** A checkpoint per module and a terminal event where each intern's service either stays up or does not, in front of the room. Stakes create retention; nothing in the current programme creates stakes.

**7.9 — Speaker notes on every slide, without exception.** Written so that any senior member of the DevOps team can deliver the session. This converts a personal talk into a transferable institutional asset and is the prerequisite for the programme scaling beyond you.

**7.10 — Fix the hygiene list in §2 regardless of whether the rebuild proceeds.** Those defects are cheap to fix and currently visible to every attendee.

---

## 8. Open items before `02-DESIGN.md`

| # | Item | Status |
|---|---|---|
| 1 | Programme shape — total duration, session length, number of sessions, cohort size | **Needed** |
| 2 | Lab environment — do interns get cloud accounts / sandbox cluster / local-only? | **Needed** |
| 3 | 2025 retrospective — where the room was lost, recurring questions, end-state capability gaps | **Needed** |
| 4 | tkxel war stories cleared for teaching use (sanitised) | **Needed** |
| 5 | Prior-rotation baseline — what Dev/Cyber/UI-UX/QA rotations already covered | Assumed from slide 4 |
| 6 | Brand constraint — tkxel template mandatory, or free rein on visual design? | **Needed** |
| 7 | Intern-photo captions and outcomes (names, projects, current roles), with consent | **Needed** |
| 8 | Confidentiality notice — legally mandatory, or relocatable to the appendix? | **Needed** |
