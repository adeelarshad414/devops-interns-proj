# Solutions

> **INSTRUCTOR-HELD. Release each day's section after that day closes.**
>
> Handing this out on Day 1 deletes the rotation. The struggle before the answer
> is where the learning happens — an intern who reads the solution to the crash
> loop has learned a fact; one who found it has learned a method.
>
> Release the whole file at T+1 as revision material. `docs/CHEATSHEET.md` is the
> version that is safe to hand out on Day 1.

Task IDs match `docs/CHARTER.md` §5.

---

## Kickoff — the crash loop

**Exercise:** `docker run --name daig-orders tkxel/daig-orders:broken`

### What happens

The container starts and exits within about a second. The room's first instinct
is to run it again. It fails again.

### The solution

```bash
# 1. observe. do not guess.
docker logs daig-orders
```

```json
{"level":"fatal","msg":"Missing required configuration: DATABASE_URL",
 "hint":"Expected postgresql://user:pass@host:5432/daig - see .env.example",
 "exit_code":78,"time":"..."}
```

```bash
# 2. confirm how it died
docker inspect daig-orders --format '{{.State.ExitCode}}'
# 78

# 3. fix the configuration, not the code
docker rm daig-orders
docker run --name daig-orders \
  -e DATABASE_URL='postgresql://daig:CHANGE_ME_DEV_ONLY@postgres:5432/daig' \
  --network daig_default \
  tkxel/daig-orders:broken
```

### Facilitation notes

- **Do not give the answer for five minutes.** The discomfort is the teaching.
- Minute 4, if nobody has read the logs: *"has anyone actually read what it said
  before it died?"* That is enough.
- The image is built with `--target broken`, which omits the dev default for
  `DATABASE_URL`. Same code as the working image.

### The debrief — the payload of the whole session

> You **observed** — you read the logs instead of guessing.
> You **hypothesised** — it cannot reach its database.
> You **changed configuration, not code.**
> You **verified** the fix.
>
> That loop, at scale, with automation around it and real money on the line, is
> the job.

Then: *"Notice nobody wrote any code. A lot of this work is knowing why software
that already works has stopped working."*

---

## Day 1 — Git, Linux, networking

### T1.4 — Find which commit introduced a change

```bash
# fastest, when you know a string that appeared or vanished
git log -S "computeSurgeScore" --oneline

# when you only know "it worked then, it does not now"
git bisect start
git bisect bad HEAD
git bisect good v0.1.0
# git checks out a midpoint; test it, then:
git bisect good      # or: git bisect bad
# repeat ~log2(n) times
git bisect reset
```

20 commits → 5 tests. Show them the maths; it lands.

### T1.5 — Recover lost work

```bash
git reflog                      # every HEAD position, including "lost" commits
git reset --hard HEAD@{2}       # or: git switch -c recovered <sha>
```

Say explicitly: **almost nothing in Git is unrecoverable, and reflog is why.** The
genuine exceptions are `git clean -fdx` on untracked files, and force-pushing over
someone else's commits.

### T1.7 — Follow one request through four layers

```bash
docker compose exec orders sh

getent hosts postgres              # 1. NAME    -> 172.x.x.x
nc -zv postgres 5432               # 2. TCP     -> open / refused / hang
curl -v localhost:3001/readyz      # 3. HTTP    -> 200 or 503
tcpdump -i any -n port 5432 -c 20  # 4. WIRE    -> SYN, SYN-ACK, or nothing
```

Four layers, four tools, four distinct failure modes. *"The database is down" is
not a diagnosis — it is a symptom with at least four possible causes.*

### T1.8 — Chaos: orders cannot reach the database

`./chaos/day1-network.sh break <1|2|3>` — three teams, three variants, nobody
told which.

#### Variant 1 — poisoned `/etc/hosts`

```bash
docker compose exec orders getent hosts postgres
# 10.255.255.1  postgres      <- wrong address
docker compose exec orders cat /etc/hosts
# ...
# 10.255.255.1 postgres       <- appended by the chaos script
```

**Tell:** the name resolves, but to an address nothing answers on. `nc` hangs
because packets go nowhere.

**Fix:** `docker compose up -d --force-recreate orders`

#### Variant 2 — iptables DROP on 5432

```bash
docker compose exec orders getent hosts postgres   # correct address
docker compose exec orders nc -zv postgres 5432    # HANGS
docker compose exec -u root orders iptables -L OUTPUT -n
# DROP  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:5432
```

**Tell:** name is fine, and `nc` **hangs** rather than refusing. A hang means
packets are being dropped silently.

**Fix:** `iptables -D OUTPUT -p tcp --dport 5432 -j DROP`, or recreate the
container.

#### Variant 3 — wrong port

```bash
docker logs daig-orders-broken
# connect ECONNREFUSED 172.x.x.x:5433
```

**Tell:** immediate **refusal**, and the port in the error message is not 5432.

**Fix:** correct the port in `DATABASE_URL`.

#### The distinction to make them say out loud

| `nc -zv` result | Means |
|---|---|
| **hangs** | packets DROPPED — firewall, NetworkPolicy, security group |
| **refused** | nothing LISTENING on that port |
| **name resolution failed** | DNS — you never reached TCP at all |

This is the most transferable thing on Day 1. Make sure it is verbalised, not
just experienced.

### Checkpoint answers — Day 1

**Q1.** DNS (`getent hosts`), routing/firewall (`nc -zv`, `traceroute -T`),
listener (`ss -tlnp` on the DB), application/auth (`docker logs`, credentials).

**Q2.** Hang = dropped. Refused = nothing listening. See table above.

**Q3.** `git bisect`, or `git log -S` if you know a distinctive string.

**Q4.** Losing work. Reflog records every HEAD position, so a "lost" commit is
still reachable for ~90 days.

---

## Day 2 — Cloud and Terraform

### T2.4 — Predict replace vs modify

```bash
terraform plan
```

Look for the annotation:

```
# aws_db_instance.main must be replaced
-/+ resource "aws_db_instance" "main" {
      ~ instance_class = "db.t4g.micro" -> "db.t4g.small"  # forces replacement
```

`~` alone = modify in place. `-/+` and `# forces replacement` = destroy and
recreate, which on a database means **data loss and downtime**.

**Ask before every apply:** *does this replace the database or modify it?*

In fact `instance_class` on RDS modifies in place with a brief failover — so this
is a good one to have them predict wrong, then read carefully. Being wrong about
it in a lab is exactly where you want to be wrong about it.

### T2.6 — Chaos: state drift

```bash
terraform plan
# ~ resource "aws_security_group" "app" {
#     - ingress { from_port = 22 ... cidr_blocks = ["0.0.0.0/0"] }
#   }
```

Terraform intends to **remove** the manual change. Three possible correct
responses:

| Response | When it is right |
|---|---|
| `terraform apply` | The manual change was a mistake. Code is the source of truth. |
| `terraform import` | Something was legitimately created by hand and should now be managed. |
| `terraform state rm` | Something Terraform manages was deliberately deleted outside it. |

**The exercise is choosing, not typing.** Here the manual change was an SSH rule
open to the world — a real security finding — so `apply` is correct, and `tfsec`
would have caught it in CI before anyone touched the console.

Make them argue it before revealing that.

### T2.7 — Largest cost line item

```bash
python3 scripts/cost-model.py
```

**AWS:** NAT Gateway at ~30% of hourly cost, then Fargate, then the ALB. NAT plus
three public IPv4 addresses is **$0.06/hr — $43.80/month — with zero containers
running.**

**GCP:** Cloud Run, because one instance stays warm. The `COST NOTE` in
`infra/gcp/variables.tf` explains why the other two now scale to zero.

**Azure:** Container Apps, but the one that surprises people is **Log Analytics at
$2.76/GB**, roughly 5× CloudWatch.

### T2.8 — Verify empty

```bash
terraform destroy
terraform state list        # should be empty
aws ec2 describe-nat-gateways --filter Name=state,Values=available
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
```

That last one catches the classic: an Elastic IP released from a NAT gateway but
still allocated, billing $3.65/month forever.

### Checkpoint answers — Day 2

**Q5.** *Does this replace the resource or modify it in place?* Look for
`# forces replacement`.

**Q6.** `apply` (manual change was wrong), `import` (adopt it), `state rm` (it was
deliberately deleted). Depends on whether the human or the code was right.

**Q7.** Cost and availability tradeoff, made explicit. Three NAT gateways cost 3×
for capacity that is mostly idle; one means private egress dies with its AZ. The
comment in `network.tf` says so.

**Q8.** NAT gateway, ALB, RDS, public IPv4 addresses, storage, and any orphaned
EIP. All bill by the hour whether or not anyone uses them.

---

## Day 3 — Ansible, Docker, networks and volumes

### T3.1 — Idempotency, discovered

```bash
ansible-playbook -i inventories/dev/hosts.yml site.yml   # many "changed"
ansible-playbook -i inventories/dev/hosts.yml site.yml   # all "ok"
```

**Do not explain first.** Ask what happened. They work it out: each task declares
a desired state and does nothing when the state already matches.

Then the question that undermines the whole approach: *what if someone SSHes in
and changes it by hand?* Nothing catches it until the next run. **That is the
bridge to containers in the afternoon.**

### T3.4 — Shrink the image

```bash
docker build -f services/orders/Dockerfile -t orders:big --target base .
docker images orders:big --format '{{.Size}}'
docker history orders:big
```

The three levers, in order of impact:

1. **Multi-stage** — build dependencies never reach the final image
2. **`npm install --omit=dev`** — no test frameworks in production
3. **alpine base** — ~40MB smaller than the default node image

Have them record both numbers. **An optimisation you did not measure did not
happen.**

### T3.5 — Layer caching

```bash
# change one line in src/server.js, rebuild
docker build -f services/orders/Dockerfile -t orders:v2 .
# → dependency layers CACHED, source layer rebuilt

# now change package.json, rebuild
docker build -f services/orders/Dockerfile -t orders:v3 .
# → everything from npm install onward rebuilds
```

That is why the Dockerfile copies `package.json` **before** the source. Point at
the two `COPY` lines.

### T3.7 — Three-tier isolation by hand

```bash
docker network create daig-frontend
docker network create --internal daig-data     # no external egress at all

docker network connect daig-data $(docker compose ps -q postgres)
docker network connect daig-frontend $(docker compose ps -q web)

# web is NOT on daig-data, so:
docker compose exec web sh -c 'nc -zv postgres 5432'
# fails - by construction, not by policy
```

**The topology enforces the three-tier model** whether or not anyone remembers it.
That sentence is the whole point of the exercise.

### T3.8 — `down` versus `down -v`

```bash
docker compose exec postgres psql -U daig -d daig \
  -c "INSERT INTO restaurants (name, area) VALUES ('Volume Test','Nowhere');"

docker compose down && docker compose up -d
docker compose exec postgres psql -U daig -d daig \
  -c "SELECT name FROM restaurants WHERE name='Volume Test';"   # STILL THERE

docker compose down -v && docker compose up -d
# ...gone. Along with everything else.
```

Two commands, one letter apart. **Let them run both.** Nobody forgets after doing
it themselves.

### T3.10 — Chaos: one symptom, three causes

`./chaos/day3-crashloop.sh break` picks a variant at random.

```bash
docker inspect daig-chaos-orders --format '{{.State.ExitCode}} {{.State.Error}}'
docker logs daig-chaos-orders
```

| Variant | Cause | Exit code | Tell |
|---|---|---|---|
| 1 | No `DATABASE_URL` | **78** | Log names the variable |
| 2 | Wrong password | 0, then unhealthy | Starts, `/readyz` 503, auth error in logs |
| 3 | `PORT=1` | non-zero | `EACCES` — ports below 1024 need privilege, and the container is non-root |

**Exit code is the fastest discriminator.** 78 means *configuration is wrong*,
which is a different class of failure from a crash — and knowing the difference
saves twenty minutes on a real incident.

### Checkpoint answers — Day 3

**Q9.** Each task declares desired state and is a no-op when it already matches.
That is idempotency.

**Q10.** `-v` deletes volumes, including the database.

**Q11.** `localhost` inside a container is *that container*. Use the service name;
Docker's embedded DNS resolves it.

**Q12.** Drift. Config management *converges* a mutable box, so a manual change
persists until the next run. A container replaces the box entirely — there is
nothing to converge.

---

## Day 4 — CI/CD and observability

### T4.2 — Make the pipeline refuse

```bash
# services/orders/test/health.test.js: change 78 to 79
git commit -am "test: deliberately break the paisa assertion"
git push
```

The `test` job fails, so `build` and `integration` never run and nothing deploys.

**Say it out loud:** *"Remember CrowdStrike? Their code shipped to every machine
on earth with no gate that could say no. You just built the gate."*

### T4.6 — Error budget from the dashboard

```
99.9% over 30 days  = 0.1% × 30 × 24 × 60  = 43.2 minutes allowed
This incident: 14 minutes
Consumed: 14 / 43.2 = 32% of the month
Remaining: 29 minutes
```

Panel: `daig:error_budget_consumed:ratio30d`. Above 0.75 the
`DaigErrorBudgetBurning` alert fires and the policy says consider a change freeze.

**The reframe:** reliability is a budget you may spend deliberately, not a virtue
you either have or lack.

### T4.9 — Chaos: two latency defects

```bash
./chaos/day4-latency.sh break
PROFILE=spike node load/iftar-spike.js
```

**Walk the pivot chain. Do not read code until step 4.**

**Step 1 — metrics.** p95 crosses the 1s SLO line. All you know: orders is slow.

```promql
histogram_quantile(0.95, sum by (le, service) (rate(daig_http_request_duration_seconds_bucket[5m])))
```

**Step 2 — traces.**

```traceql
{ resource.service.name = "orders" && duration > 1s }
```

`dispatch` owns ~8 of 9 seconds, and inside it are dozens of sequential
`count_rider_load` DB spans, stacked end to end. **That shape is an N+1 query.**

**Step 3 — logs.** Click from the trace to that trace id's log lines.

**Step 4 — profiles.** Open the flame graph for the `kitchen` span.
`computeSurgeScore` is ~71% of CPU. *Now* read the code, and the nested loop is
obvious.

#### Defect A — `dispatch`, N+1

`services/dispatch/src/server.js`, `pickRider()` under
`CHAOS_SLOW_DISPATCH=true`: one query for riders, then one per rider.

```sql
-- the missing index, commented out in db/init/001_schema.sql
CREATE INDEX idx_assignments_order ON assignments(order_id);
CREATE INDEX idx_orders_state_created ON orders(state, created_at DESC);
```

The real fix is the grouped single query already in the `!slow` branch.

#### Defect B — `kitchen`, O(n²)

`computeSurgeScore()` under `CHAOS_HOT_SURGE_LOOP=true` loops the same array
twice. The `Map`-based version in the `!chaos` branch is O(n).

#### Measure

```bash
./chaos/day4-latency.sh fix
PROFILE=spike node load/iftar-spike.js
```

**Screenshot p95 before and after. The delta is the deliverable.**

#### Why two defects, deliberately

Defect A is visible **only in traces** — it is many fast queries, not one slow
function. Defect B is visible **only in profiles** — it is CPU inside a single
span. Metrics detect both as "orders is slow" and distinguish neither.

**That is the proof that four pillars are not padding.**

### T4.10 — Cardinality

Add `order_id` as a label, generate load, then:

```promql
count({__name__="daig_http_request_duration_seconds_count"})
```

Series count explodes — one per order, per bucket. Remove it. Five minutes that
prevents a real incident later.

### Checkpoint answers — Day 4

**Q13.** Traces say *where*. Profiles say *which line*.

**Q14.** 43 minutes. A 14-minute incident spent ~32%; ~29 remain. Above 75%
consumed, consider a change freeze.

**Q15.** **Refuse to deploy.** Everything else it does is secondary.

**Q16.** Unbounded cardinality — one time series per order, per bucket, per label
combination. It melts the index.

---

## Day 5 — DevSecOps

### T5.2 — Triage

```bash
./chaos/day6-security.sh break
./security/scan-all.sh sast
```

| # | CWE | Vulnerability | Found by | Real? | Impact here |
|---|---|---|---|---|---|
| 1 | 89 | SQL injection | Semgrep, CodeQL, ZAP | Yes | Read/modify any data |
| 2 | 639 | **IDOR** | **nothing** | Yes | Read any customer's order |
| 3 | 209 | Stack trace + `DATABASE_URL` in response | Semgrep, ZAP | Yes | Free reconnaissance, credential leak |
| 4 | 327 | MD5 password hash | Semgrep, CodeQL | Yes | Offline cracking is trivial |
| 5 | 770 | No rate limiting | nothing automated | Yes | DoS, and cost |
| 6 | 918 | SSRF | Semgrep, CodeQL | Yes | Reach IMDS → cloud credentials |

### T5.3 — The one no scanner found

**VULN-2, the IDOR** in `GET /insecure/orders/:id`.

**Why no tool finds it:** the SQL is parameterised, there is no unsafe call,
nothing is locally wrong. What is *missing* is a business rule — nobody checked
that the requester owns the order. A scanner cannot know your authorisation model.

```js
// vulnerable: any caller, any order
const { rows } = await q('...', 'SELECT * FROM orders WHERE id = $1', [req.params.id]);

// fixed: scoped to the authenticated caller
const { rows } = await q('...',
  'SELECT * FROM orders WHERE id = $1 AND customer_id = $2',
  [req.params.id, req.user.id]);
```

It is **#1 on the OWASP API Security Top 10** for exactly this reason.

**The line that carries the day:**

> Tools find classes of bug. Humans find missing rules. That is why you still read
> each other's code.

### T5.4 — Fix three properly

| # | The wrong fix | The right fix |
|---|---|---|
| 1 | Escape quotes, reject apostrophes | **Never concatenate.** Pass `$1` parameters. |
| 3 | Remove the `stack` field | Log the detail with a UUID; return `{error, reference}` |
| 4 | SHA-256 instead of MD5 | **argon2id**, or bcrypt/scrypt with a cost factor. A password hash should be *slow*. |
| 6 | Block `169.254.169.254` | Allowlist hostnames, https only, resolve DNS and reject private/link-local, short timeout, require IMDSv2 |

Fix 1 is the important teaching moment: the answer to SQL injection is not better
escaping, it is not building SQL by concatenation at all.

### T5.5 / T5.6 — Write the gate

```yaml
# add to security/semgrep/daig.yml
- id: daig-missing-ownership-check
  languages: [javascript]
  severity: WARNING
  message: >-
    Query on the orders table with no ownership predicate. Confirm the caller is
    authorised to read this row. See CWE-639.
  patterns:
    - pattern-regex: 'FROM orders WHERE id = \$1(?!.*customer_id)'
```

Imperfect — a regex cannot really express authorisation. **That imperfection is
the lesson:** you can gate the *shape* of the mistake even when you cannot gate
the concept.

**T5.6** — complete `daig-direct-pool-query`:

```yaml
  - id: daig-direct-pool-query
    languages: [javascript]
    severity: WARNING
    message: "Use the timed q() helper so the query appears in daig_db_query_duration_seconds."
    pattern: $POOL.query(...)
    paths:
      exclude: [services/_shared/db.js]
```

**Where the repo breaks its own convention:** `services/orders/src/server.js`, the
`POST /api/orders` transaction uses `client.query(...)` directly for `BEGIN`,
the inserts, and `COMMIT` — so none of those appear in the query-duration metric.

Defensible (a transaction needs one pinned client) but it means the most
important write path in the system is unmeasured. **Good finding. Let them argue
whether it should be fixed.**

### T5.7 / T5.8 — Vault

```bash
make vault-up
docker compose -f docker-compose.yml -f docker-compose.vault.yml \
  exec openbao tail -5 /openbao/logs/audit.log
```

Least privilege, demonstrated:

```bash
# log in as dispatch, then attempt a read the policy denies
bao kv get daig/app
# Error: permission denied
```

`dispatch` may read `daig/database` and nothing else. If it is compromised, the
attacker gets a database host — not the JWT signing key, not the payment
credentials.

### T5.10 — Watch verification fail

```bash
./security/sign-and-verify.sh ghcr.io/adeelarshad414/daig/orders:sha
```

The script deliberately ends by verifying `nginx:latest`, which nobody signed, and
failing. **A gate you have never seen fire is not a gate you trust.**

### Checkpoint answers — Day 5

**Q17.** It is a missing business rule, not a wrong code pattern. No tool knows
your authorisation model.

**Q18.** A secret store — OpenBao/Vault, or the cloud equivalent. Not an
environment variable: environment variables appear in `docker inspect`, in crash
dumps, in process listings, in logs, and they never expire.

**Q19.** Makes it worthless. The credential expired at 10:00.

**Q20.** **Write a gate** — a test, a Semgrep rule, an OPA policy — so it cannot
regress. A fix without a gate is gone in two sprints.

---

## Day 6 — Kubernetes and Demo Day

### T6.7 / T6.8 — Why the rollout stalls

```bash
kubectl -n daig set image deploy/orders orders=ghcr.io/tkxel/daig-orders:v9-nope
kubectl -n daig rollout status deploy/orders     # stalls
kubectl -n daig get pods                          # new pod ImagePullBackOff, old still Running
kubectl -n daig rollout undo deploy/orders
```

**The two settings**, in `k8s/base/orders.yaml`:

```yaml
strategy:
  rollingUpdate:
    maxUnavailable: 0        # never drop below full capacity
readinessProbe:              # a pod that is not Ready gets no traffic
  httpGet: { path: /readyz, port: http }
```

Together: the new pods never become Ready, so the old pods keep serving and
traffic never moves. **The platform refused to finish a bad deploy** — the
CrowdStrike lesson expressed as configuration.

### T6.9 — Demo Day: the nine scenarios

The method that works on all nine:

```bash
kubectl -n <ns> get pods                     # state? restart count?
kubectl -n <ns> describe pod <pod>           # EVENTS AT THE BOTTOM. read first.
kubectl -n <ns> logs <pod> --previous        # what the dead one said
kubectl -n <ns> get endpoints <svc>          # empty = selector problem
kubectl -n <ns> get events --sort-by=.lastTimestamp
```

| # | Cause | Fastest tell | Fix |
|---|---|---|---|
| 1 | Image tag does not exist | `describe` → `ImagePullBackOff` | `rollout undo` |
| 2 | Secret key renamed | `describe` → `CreateContainerConfigError`, names the key | restore the key |
| 3 | Memory limit 16Mi | `describe` → last state `OOMKilled` | raise the limit |
| 4 | Readiness probe wrong port | `Running` but `0/1`; probe failure in events | correct the port |
| 5 | Service selector typo | **`get endpoints` is empty** | fix the selector |
| 6 | Replicas 0 | No pods, **no errors anywhere** | `scale --replicas=3` |
| 7 | ConfigMap wrong DB host | exit **78** in `logs --previous` | fix the ConfigMap |
| 8 | CPU limit 50m | Pods healthy, latency terrible. **Only metrics show it.** | raise the limit |
| 9 | NetworkPolicy denies egress | Readiness 503 and **nothing in any log explains why** | delete the policy |

**Scenarios 6 and 9 are the hardest, for opposite reasons.** 6 has no error at
all; 9 has an error with no stated cause. Save them for whoever is clearly ahead.

**Scenario 5 is the one worth teaching everyone:** `get endpoints` is the single
fastest diagnostic in Kubernetes and almost nobody reaches for it.

### T6.10 — The postmortem template

```markdown
## What happened
One paragraph, no jargon. A non-engineer should follow it.

## Impact
Who could not do what, for how long.

## Timeline
14:02  alert fired / symptom noticed
14:04  first hypothesis: X
14:07  ruled out X because Y
14:11  found the cause
14:14  fix applied, verified

## Root cause
The system-level reason. Not a person.

## What we ruled out, and how
This section is worth more than the root cause. It shows the method.

## Prevention
What gate stops this recurring? A test, an alert, a policy, a probe.
```

**Blameless does not mean nobody is accountable.** It means you go after the
system that allowed the mistake, not the person who made it — because that person
understands it best, and if you punish them they will hide the next one.

### Checkpoint answers — Day 6

**Q21.** `Running` = the container process started. `Ready` = the readiness probe
passes and the Service will send it traffic. A pod can be Running and never Ready.
`describe` events say why.

**Q22.** `maxUnavailable: 0` and the `readinessProbe`.

**Q23.** No pod matches the Service selector — a label typo, or zero replicas.

**Q24.** A liveness probe that checks the database fails for every instance at
once when the database is slow, so the orchestrator kills them all and a
*degradation* becomes an *outage*. Readiness is the right place: remove the
instance from the load balancer, do not kill it.

---

## Cross-cutting answers

### Q1 — What problem does DevOps solve?

Software that ships badly breaks things that matter. CrowdStrike, 19 July 2024:
not a hacker, not a breach, not really a bug — a configuration update pushed to
every customer at once with no staged rollout and no blast-radius control. **A
shipping failure, not a coding failure.**

### Q2 — The four disciplines

One incident, 18:42, iftar in eighteen minutes, orders returning 503s:

| Role | The question they ask |
|---|---|
| **DevOps** | How do we get this working again, now? |
| **SRE** | How much failure can we afford before we stop shipping? |
| **Platform** | Why was it even possible to deploy at 17:30 on a Thursday? |
| **Cloud/FinOps** | We survived by tripling instances. What did that cost? |

**DevOps fixes today. SRE decides what "good enough" means. Platform makes it
structurally impossible. FinOps asks what surviving cost.**

Then: *"You will do all four this week. You will specialise later. You do not have
to pick today."*

### Q3 — How do I find out why, without guessing?

The diagnostic ladder in `docs/CHEATSHEET.md`. Symptom → logs → exit code →
name/route/port → metrics then traces → what changed. Restarting is step 7.

### Q4 — How do I know if it is reliable enough?

An SLO plus an error budget. 99.9% over 30 days = 43 minutes. Reliability is a
budget you may spend deliberately, not a virtue.

### Q5 — How does code reach production safely?

Seven gates ordered by cost of feedback, then a deploy-window guard, then a canary
at 10% watched against real SLO metrics, then 100%, with one-step rollback that
needs no rebuild.

### Q6 — Where do credentials live?

In a secret store, fetched at startup via an identity the service proves rather
than a token it holds. Short TTLs, least privilege per service, every read
audited. **Not** in environment variables, not in Git, not in an image layer.

---

## For the instructor: the three sentences that matter most

Everything else is scaffolding around these.

1. **"Tools find classes of bug. Humans find missing rules."** — Day 5, and the
   reason code review exists.
2. **"Reliability is a budget, not a virtue."** — Day 4, and the whole of SRE.
3. **"A pipeline people work around protects nobody."** — Day 5, and the reason
   gate ordering matters more than gate count.

If the cohort leaves with those three and nothing else, the rotation worked.
