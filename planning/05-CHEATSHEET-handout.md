# Cheat sheet

**Hand this out on Day 1.** It contains commands, not answers — the exercises
still work with this open in front of you. Worked solutions are in
the private solutions repo, released after each day closes.

Print it. You will use it more than any slide.

---

## The diagnostic ladder

**When something is broken, work down this list in order.** Do not skip. Do not
restart anything until you reach step 6.

| # | Question | Where you look |
|---|---|---|
| 1 | What exactly is the symptom? | `curl -v`, the actual error, the HTTP code |
| 2 | What did it say before it died? | `docker logs`, `kubectl logs --previous`, `journalctl` |
| 3 | How did it exit? | `docker inspect --format '{{.State.ExitCode}}'`, `describe` events |
| 4 | Is it a name, a route, or a port? | `getent hosts`, `ping`, `nc -zv`, `ss -tlnp` |
| 5 | Is it slow or is it broken? | metrics first, then a trace |
| 6 | What changed, and when? | `git log`, deploy history, `terraform plan` |

**Restarting things is step 7 and it is an admission of defeat.** Sometimes it is
the right answer. It is never the first answer.

### The one distinction to memorise

```
nc -zv host 5432   →  hangs           = packets DROPPED (firewall)
nc -zv host 5432   →  refused         = nothing LISTENING on that port
nc -zv host 5432   →  name resolution = DNS problem, you never reached TCP
```

Three different causes, three different fixes, and this one command tells them
apart in two seconds.

---

## Git

```bash
# workflow
git switch -c feat/thing            # new branch
git add -p                          # stage HUNK by hunk. read your own diff.
git commit -m "feat(orders): ..."   # conventional commit
git push -u origin feat/thing

# investigation - this is the half nobody teaches
git log --oneline --graph -20       # what happened recently
git log -S "functionName"           # when did this string appear or vanish?
git log -p -- path/to/file          # every change to one file, with diffs
git blame path/to/file              # who wrote this line, and when
git diff HEAD~5..HEAD -- services/  # what changed in the last 5 commits

# find the bad commit in log2(n) steps
git bisect start
git bisect bad HEAD
git bisect good <known-good-sha>
#   ...test, then: git bisect good  |  git bisect bad  ...repeat
git bisect reset

# undo. almost nothing is unrecoverable.
git reflog                          # EVERYTHING you have done, incl. "lost" work
git reset --hard HEAD@{2}           # go back to a previous state
git revert <sha>                    # undo a commit that is already pushed
git restore --staged <file>          # unstage, keep changes
git stash / git stash pop           # park work, switch, come back

# conflicts
git log --merge -p <file>            # both sides' history
git checkout --ours / --theirs <f>  # when you know which side wins
git merge --abort                   # the escape hatch
```

**Conventional commits:** `feat` `fix` `docs` `refactor` `test` `chore` `perf`
`ci` `security`, optional `(scope)`.

---

## Linux

```bash
# processes
ps aux --sort=-%cpu | head          # who is busy
top -o %CPU                          # live
kill -TERM <pid>                    # ask nicely first
kill -9 <pid>                       # only when TERM fails

# what is listening
ss -tlnp                            # TCP, listening, with process
ss -tnp state established           # current connections
lsof -i :3001                       # who owns this port

# disk - the most common 3am page
df -h                               # filesystem usage
du -sh * | sort -h                  # what is big, here
du -sh /var/lib/docker              # usually the answer

# network path
getent hosts postgres               # name -> address (uses the real resolver)
dig postgres +short                 # DNS detail
nc -zv postgres 5432                # can I open a TCP connection?
curl -v http://orders:3001/readyz   # does the app layer answer?
tcpdump -i any -n port 5432 -c 20   # what is actually on the wire
traceroute -T -p 5432 postgres      # where does it stop

# logs
journalctl -u docker -n 50 --no-pager
journalctl -u docker --since "10 min ago"
tail -f /var/log/nginx/access.log

# permissions
ls -la; id; namei -l /path/to/file  # namei shows every component's perms
```

---

## Docker

```bash
# containers
docker ps -a                                     # incl. dead ones
docker logs -f --tail=100 <name>
docker logs <name> --since 5m
docker inspect <name> --format '{{.State.ExitCode}} {{.State.Error}}'
docker inspect <name> --format '{{json .State.Health}}'
docker exec -it <name> sh
docker stats                                     # live resource use

# images
docker build -f services/orders/Dockerfile -t mine:v1 .
docker build --target broken -t mine:broken .    # a specific stage
docker images | grep daig
docker history mine:v1                            # layers, and their size
docker image inspect mine:v1 --format '{{.Config.User}}'

# networks
docker network ls
docker network inspect daig_default
docker network create --internal daig-data       # no external egress at all
docker network connect / disconnect <net> <container>

# volumes
docker volume ls
docker volume inspect daig_pgdata
docker system df                                  # what is using disk
docker system prune -a --volumes                 # DANGEROUS. read the prompt.

# exit codes you will meet
#   0    clean exit
#   1    generic error
#   78   EX_CONFIG - configuration is wrong (this repo uses it deliberately)
#   125  docker itself failed
#   126  command not executable
#   127  command not found
#   137  SIGKILL - usually OOM
#   143  SIGTERM - graceful shutdown
```

### Compose

```bash
docker compose up -d --build
docker compose up -d --force-recreate --no-deps orders   # one service only
docker compose ps
docker compose logs -f --tail=80 orders
docker compose exec postgres psql -U daig -d daig
docker compose config                    # the merged, resolved config
docker compose down                      # keeps volumes
docker compose down -v                   # DELETES volumes
docker compose -f a.yml -f b.yml up -d   # overlays; later wins
```

---

## Terraform

```bash
terraform init
terraform init -backend=false            # validate without touching state
terraform validate
terraform fmt -recursive
terraform plan                            # READ THIS. EVERY LINE.
terraform plan -out=tfplan
terraform show -json tfplan > plan.json  # for policy checks
terraform apply
terraform destroy                         # every evening. no exceptions.

# state
terraform state list
terraform state show aws_db_instance.main
terraform import aws_s3_bucket.x my-bucket   # adopt something made by hand
terraform state rm aws_s3_bucket.x           # forget something deleted by hand
terraform refresh                             # reconcile state with reality

# targeting - useful in a lab, a smell in production
terraform apply -target=aws_db_instance.main
```

**Before every apply, ask one question:** *does this REPLACE the database or
MODIFY it in place?* Look for `# forces replacement` in the plan.

---

## Ansible

```bash
ansible-playbook -i inventories/dev/hosts.yml site.yml
ansible-playbook ... --check --diff        # dry run, show changes
ansible-playbook ... --limit app-01
ansible-playbook ... --tags docker
ansible-playbook ... -vv                   # more output
ansible all -i inventories/dev/hosts.yml -m ping
ansible-inventory -i inventories/dev/hosts.yml --graph
```

**Run any playbook twice.** The second run should report `ok`, not `changed`.
If it says `changed` again, a task is not idempotent.

---

## Observability

### PromQL

```promql
# request rate by service
sum by (service) (rate(daig_http_request_duration_seconds_count[1m]))

# p95 latency by service
histogram_quantile(0.95,
  sum by (le, service) (rate(daig_http_request_duration_seconds_bucket[5m])))

# error rate
sum(rate(daig_http_request_duration_seconds_count{status=~"5.."}[5m]))
  / sum(rate(daig_http_request_duration_seconds_count[5m]))

# the recording rules this repo defines
daig:order_availability:ratio5m
daig:error_budget_consumed:ratio30d
daig:order_latency:p95_5m

# database time by operation - this is where the N+1 shows up
histogram_quantile(0.95,
  sum by (le, op) (rate(daig_db_query_duration_seconds_bucket[5m])))
```

### LogQL

```logql
{project="daig"}                                  # everything
{service="orders"} | json | level="error"
{project="daig"} | json | trace_id="abc123..."    # one request's logs
{service="dispatch"} | json | line_format "{{.msg}}"
sum(rate({project="daig"} | json | level="error" [5m])) by (service)
```

### TraceQL

```traceql
{ resource.service.name = "orders" }
{ resource.service.name = "orders" && duration > 500ms }
{ span.http.status_code >= 500 }
{ name =~ "pick_rider.*" && duration > 1s }
```

### The pivot chain

```
metrics say SOMETHING is wrong  →  click through to a slow trace
trace says WHERE                →  click through to that trace's logs
logs say WHAT                   →  click through to the span's profile
profile says WHICH LINE
```

Four clicks. Do not read code before step 4.

### Error budget arithmetic

| SLO | Allowed downtime per 30 days |
|---|---|
| 99% | 7 h 18 min |
| **99.9%** | **43 minutes** |
| 99.95% | 21 min 54 s |
| 99.99% | 4 min 20 s |

---

## Kubernetes

```bash
# the four commands that solve most problems
kubectl -n daig get pods
kubectl -n daig describe pod <pod>          # READ THE EVENTS AT THE BOTTOM
kubectl -n daig logs <pod> --previous       # what the DEAD one said
kubectl -n daig get endpoints <svc>         # empty = selector problem

kubectl apply -k k8s/base
kubectl -n daig get pods -w
kubectl -n daig get events --sort-by=.lastTimestamp

# scale, roll, undo
kubectl -n daig scale deploy/orders --replicas=5
kubectl -n daig set image deploy/orders orders=repo/img:tag
kubectl -n daig rollout status deploy/orders
kubectl -n daig rollout history deploy/orders
kubectl -n daig rollout undo deploy/orders

# poke around
kubectl -n daig exec -it <pod> -- sh
kubectl -n daig port-forward svc/orders 3001:3001
kubectl -n daig get pod <pod> -o yaml
kubectl -n daig top pod

# states, and what they mean
#   Pending            no node can take it (resources, taints, PVC unbound)
#   ContainerCreating  pulling the image or mounting volumes
#   Running 0/1        the container is up but readiness is FAILING
#   CrashLoopBackOff   it starts, dies, and k8s is backing off
#   ImagePullBackOff   tag does not exist, or no pull credentials
#   OOMKilled          exceeded its memory limit
#   Error              exited non-zero. Check the code.
#   CreateContainerConfigError  a Secret or ConfigMap key is missing
```

### Docker Swarm

```bash
docker swarm init
docker stack deploy -c swarm/daig-stack.yml daig
docker stack services daig
docker service ps daig_orders
docker service logs -f daig_orders
docker service scale daig_orders=6
docker service update --image repo/img:v2 daig_orders
docker service rollback daig_orders
docker stack rm daig
```

| Swarm | Kubernetes |
|---|---|
| service | Deployment + Service |
| task | Pod |
| `docker service scale` | `kubectl scale` |
| `update_config` | `strategy.rollingUpdate` |
| overlay network | ClusterIP + NetworkPolicy |
| routing mesh | Service + kube-proxy |
| manager / worker | control plane / node |

---

## OpenBao (Vault)

```bash
make vault-up            # start, init, unseal, provision
make vault-ui            # URL and root token
make vault-demo          # guided walkthrough

# inside the container
export BAO_ADDR=http://127.0.0.1:8200
bao status
bao kv get daig/database
bao kv put daig/database password=...
bao kv metadata get daig/database     # version history
bao kv rollback -version=1 daig/database
bao policy list / read daig-orders
bao audit list
bao token lookup

# AppRole login, which is what a service does
bao write -f auth/approle/login \
  role_id=<id> secret_id=<id>

# the audit log answers "who read this, and when"
tail -5 /openbao/logs/audit.log
```

---

## Security scanning

```bash
./security/scan-all.sh              # everything
./security/scan-all.sh secrets      # gitleaks, ~20s
./security/scan-all.sh sast         # semgrep
./security/scan-all.sh deps         # npm audit, OSV
./security/scan-all.sh image        # trivy
./security/scan-all.sh iac          # trivy config + conftest
./security/scan-all.sh sbom         # syft

# individual tools
semgrep --validate --config security/semgrep/daig.yml   # check the rules parse
semgrep scan --config security/semgrep/daig.yml services/
conftest test --policy security/policy k8s/base/
trivy image --severity HIGH,CRITICAL <image>
cosign verify <image> --certificate-identity-regexp ... --certificate-oidc-issuer ...
syft <image> -o cyclonedx-json
```

**A finding is not a vulnerability until you can say what it lets someone do.**
Triage in three questions: is it real, is it reachable, what is the impact *here*?

---

## Repo commands

```bash
make help          # every target, self-documenting
make check         # static checks, no Docker needed
make up seed smoke
make obs           # observability
make load          # iftar spike
make vault-up vault-app
make scan          # security toolchain
make broken        # the kickoff exercise image
make down          # stop, keep data
make nuke          # stop, DELETE data

python3 scripts/cost-model.py
```

---

## Things that will bite you

| Symptom | Almost always |
|---|---|
| `localhost` does not work inside a container | `localhost` is that container. Use the service name. |
| Container exits instantly, no useful log | Read it again with `docker logs`. It told you. |
| Exit code 78 | Configuration is missing or wrong. Not a crash. |
| Exit code 137 | OOM. Raise the memory limit or fix the leak. |
| Pod `Running` but `0/1` | Readiness probe failing. `describe` shows why. |
| `kubectl get endpoints` empty | Service selector does not match pod labels. |
| Bind mount permission denied | Container runs as uid 1000; host dir owned by root. |
| Terraform wants to replace the database | Read which attribute forces it before you apply. |
| Ansible reports `changed` on every run | A task is not idempotent. Usually `shell` or `command`. |
| Everything worked, then stopped, nobody deployed | Something expired. Certificate, token, or credential TTL. |
| `nc` hangs rather than refusing | Packets dropped. Firewall or NetworkPolicy. |

---

## Ask for help after 15 minutes

Not before — the struggle is doing the teaching. Not after 45 — that is just
being stuck.

When you ask, bring three things:

1. What you expected
2. What happened, with the actual error
3. What you have already ruled out, and how

That format is also a postmortem, an incident update, and a good bug report. Learn
it once, use it for your whole career.
