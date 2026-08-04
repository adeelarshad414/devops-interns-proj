# Deployment

Procedures per environment, plus rollback. Read `VERIFICATION.md` first —
**none of this has been executed.**

---

## Environments

| Environment | Runs on | Credentials | Who deploys |
|---|---|---|---|
| **Local** | Docker Compose | `.env`, or OpenBao overlay | Anyone, any time |
| **Staging** | One cloud, one stack | Cloud secret store | CI on merge to `main` |
| **Production** | Kubernetes or managed containers | Vault / cloud secret store | CD, manual dispatch, signed images only |

Daig has no real production. The production column describes what the pipeline is
*shaped for*, so interns see the whole path rather than a truncated one.

---

## Local

### First run

```bash
cp .env.example .env
make up          # three tiers
make seed        # reference data
make smoke       # verify every tier
```

### With observability

```bash
make obs
make load        # generate the iftar curve
# Grafana http://localhost:3000  admin / CHANGE_ME_DEV_ONLY
```

### With OpenBao instead of environment credentials

```bash
make vault-up     # start, initialise, unseal, provision
make vault-app    # restart the services against OpenBao

docker compose logs orders | grep credential_source
# expect: "credential_source":"openbao"
```

If that says `environment`, the integration is not working. The log line above it
will say why — the loader refuses to fall back silently, so the failure is loud.

### Teardown

```bash
make down        # stop, keep volumes
make nuke        # stop and DELETE volumes, including the database
```

`nuke` and `down` are one letter apart in effect and one of them destroys your
data. Day 3 has interns run both deliberately, because nobody forgets after doing
it themselves.

---

## Staging

### Prerequisites, in order

1. A cloud account **with a budget alert already configured.** Ten dollars of
   alerting prevents a four-figure surprise. Before the first `apply`, not after.
2. Remote Terraform state. The backend block is commented out in each
   `versions.tf` — uncomment and create the bucket or storage account first.
   Local state is fine for one person and wrong the moment two people touch the
   same infrastructure.
3. CI OIDC configured, so no long-lived cloud keys live in repository secrets.

### Provision

```bash
cd infra/aws                 # or gcp, or azure
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan               # read every line before applying
terraform apply
```

**Read the plan.** The question to ask on every change: *does this replace the
database or modify it in place?* Asking it before every apply is the difference
between a routine change and an outage.

### Deploy the application

Images are built and pushed by `.github/workflows/ci.yml` and
`devsecops.yml`. Deployment is a service update, per platform:

| Platform | Command |
|---|---|
| AWS ECS | `aws ecs update-service --force-new-deployment` |
| GCP Cloud Run | `gcloud run services update daig-orders --image=...` |
| Azure Container Apps | `az containerapp update -n ca-orders --image ...` |
| Kubernetes | `kubectl -n daig set image deploy/orders orders=...` |

### Teardown — every day

```bash
terraform destroy
```

Put this in the Day 2 checklist. The standing charges are managed Postgres, the
NAT gateway (AWS), the VPC connector (GCP) and the Container Apps environment
(Azure). They bill whether or not anyone touches Daig.

All monthly figures in this repository derive from **730 hours/month**. Use that
constant consistently or your numbers will not reconcile with the invoice.

---

## Production shape

### The gate chain

```
push → secrets → SAST → SCA → IaC/policy → image+SBOM+sign → DAST → deploy window → canary → 100%
       ~20s      ~2m    ~1m    ~1m          ~3m               ~5m
```

Ordered by cost of feedback, cheapest first. `.github/workflows/devsecops.yml`.

### The deploy-window guard

`.github/workflows/cd.yml` refuses to deploy between **16:00 and 21:00 PKT** —
the iftar peak. Overriding requires a documented change request.

This is the platform engineer's answer from the kickoff deck: do not ask people
to remember not to deploy before dinner, make it impossible.

### Progressive delivery

| Stage | Traffic | Gate |
|---|---|---|
| Canary | 10% | 5 minutes of SLO observation |
| Full | 100% | Only if the canary was healthy |
| Rollback | 0% | Automatic on failure |

Per platform:

- **Kubernetes** — Argo Rollouts or Flagger; or `maxUnavailable: 0` plus a
  readiness probe, which makes a bad rollout stall rather than complete
- **ECS** — CodeDeploy blue/green, or the deployment circuit breaker with
  `rollback = true` (already configured in `infra/aws/compute.tf`)
- **Cloud Run** — `gcloud run services update-traffic --to-revisions=NEW=10`
- **Container Apps** — `az containerapp ingress traffic set --revision-weight NEW=10`

**A canary you do not measure is just a slow deploy.** The watch step must query
real SLO metrics, not sleep.

### Annotate the deploy

Currently a TODO in `cd.yml`, and worth doing: every dashboard should show when a
deploy happened. Half of all incident diagnosis is *what changed, and when*.

---

## Rollback

| Platform | Command | Time |
|---|---|---|
| Kubernetes | `kubectl -n daig rollout undo deploy/orders` | ~30s |
| ECS | Circuit breaker, automatic; or update to the previous task definition | ~2m |
| Cloud Run | `gcloud run services update-traffic --to-revisions=PREVIOUS=100` | ~10s |
| Container Apps | `az containerapp revision set-mode --mode single --revision PREVIOUS` | ~30s |
| Swarm | `docker service rollback daig_orders` | ~30s |

**Rollback must never require a rebuild.** If rolling back means waiting for CI,
you do not have a rollback — you have a slow forward fix. NFR-31.

### Database rollback

There isn't one, and that is the point. Schema changes are additive only, so the
previous application version keeps working against the new schema. That property
is what makes application rollback safe, and it is why the additive-only rule is
non-negotiable rather than a style preference.

---

## Kubernetes

```bash
kubectl apply -k k8s/base
kubectl -n daig rollout status deploy/orders
kubectl -n daig get pods -w
```

### Before production, three things that are not in `k8s/base/`

1. **A real secrets mechanism.** `k8s/base/secret.yaml` is a labelled teaching
   artifact with inline `stringData`. Production needs External Secrets Operator,
   Sealed Secrets, or the cloud CSI driver.
2. **Kyverno in `Enforce`.** `security/kyverno/policies.yaml` ships the image
   signature policy as `Audit`. Move it to `Enforce` once the cluster is clean —
   and confirm it actually rejects something before trusting it.
3. **Managed Postgres.** `k8s/base/postgres.yaml` is a single-replica StatefulSet,
   which is fine for teaching and wrong for production. Use what `infra/`
   provisions.

---

## Deployment checklist

Before:

- [ ] CI green, including all seven security gates
- [ ] Image signed; SBOM attached
- [ ] Outside the 16:00–21:00 PKT window
- [ ] Someone is actually on call, and knows it
- [ ] Error budget has room (below 75% consumed)
- [ ] Rollback path tested, not assumed

After:

- [ ] Canary healthy for 5 minutes against real SLO metrics
- [ ] Deploy annotated on the dashboards
- [ ] Error rate and p95 unchanged at 100%
- [ ] Alerts quiet

If any "before" box is unchecked, the deploy waits. That is not bureaucracy — it
is the shortest available description of how the 19 July 2024 outage happened.
