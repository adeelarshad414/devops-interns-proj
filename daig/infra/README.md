# Infrastructure as Code

One runnable stack per cloud, deploying the same three tiers. They are
deliberately parallel so that Tuesday can make the point that matters:

> The concepts are identical. Only the nouns change.

| Concept | AWS | GCP | Azure |
|---|---|---|---|
| Network | VPC + subnets | VPC + subnet | VNet + subnets |
| Run containers | ECS Fargate | Cloud Run | Container Apps |
| Managed Postgres | RDS | Cloud SQL | PostgreSQL Flexible Server |
| Image registry | ECR | Artifact Registry | ACR |
| Secrets | Secrets Manager | Secret Manager | Key Vault |
| Ingress | ALB | Cloud Run URL | Container Apps ingress |
| Identity for CI | IAM role + OIDC | Workload Identity Federation | Managed Identity + OIDC |

An intern who has provisioned one of these can read the other two. That
transferability is worth more than depth in any single provider, and it is the
argument for teaching the pattern rather than the console.

## Warning, stated plainly

**None of this has been executed.** No `init`, no `validate`, no `plan`, no
`apply`. There was no Terraform binary in the environment where it was written.
See `VERIFICATION.md`.

Before Tuesday, someone must run at least the AWS stack end to end. Expect to
fix provider version constraints and at least one argument name - the providers
move faster than any written material.

## Security posture (audit fixes)

Baseline items a real stack expects, added across all three clouds:

- **DB TLS enforced**, not just requested — AWS via `sslmode=require` + an
  `rds.force_ssl=1` parameter group; GCP via `ssl_mode = "ENCRYPTED_ONLY"`; Azure
  already required it. The server rejects cleartext, rather than trusting the
  client to opt in.
- **AWS VPC flow logs** to CloudWatch — "what talked to what, and when" is
  unanswerable after an incident without them.
- **ECS autoscaling doesn't fight Terraform** — `aws_ecs_service` uses
  `lifecycle { ignore_changes = [desired_count] }`, so a `terraform apply` during
  the iftar spike won't reset live capacity to the static count.

Still deliberately left for the class (see `PROGRESS.md`): remote state backends
(commented), ALB TLS, single NAT — all annotated tradeoffs.

## Cost

Full model, computed rather than asserted: [`../docs/COST.md`](../docs/COST.md)

```bash
python3 ../scripts/cost-model.py
```

Short version: **about $5 per cloud for the whole rotation** if you only bring
infrastructure up on Day 2 and Day 6, and destroy it each evening. About $1,900
if twenty interns each apply a stack and nobody destroys anything for a month.

## Cost, before anyone runs anything

Every stack defaults to the smallest instance sizes that work. Even so:

- **Managed Postgres is the expensive line item** in all three clouds. It is
  also the one interns will forget to destroy.
- `terraform destroy` at the end of every day. Put it in the Day 2 checklist.
- Set a **budget alert before the first `apply`**, not after. Ten dollars of
  alerting prevents a four-figure surprise.
- All monthly figures in this repo derive from **730 hours/month**. Use that
  constant consistently or your numbers will not reconcile with the bill.

## Order of work on Tuesday

1. Provision by hand in the console. Deliberately. Feel the tedium.
2. Destroy it by hand. Notice what you forget.
3. Do it again with Terraform. Notice the relief.
4. Change one variable, read the plan, apply.
5. `./chaos/day2-drift.sh <cloud>` - reconcile state against reality.

Console first is not wasted time. It is what makes step 3 land.
