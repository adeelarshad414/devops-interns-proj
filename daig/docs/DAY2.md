# Day 2 - Cloud & Infrastructure as Code

> **Daig chapter:** Daig needs somewhere to live. Click it into existence once,
> then never again.

## Morning - do it the slow way, on purpose

Provision Daig's infrastructure **by hand in the console**. All of it: network,
subnets, security groups, database, container runtime.

This looks like wasted time and it is not. Two things happen:

1. You will make a mistake and not notice for twenty minutes.
2. You will not be able to remember exactly what you clicked.

Then **destroy it by hand** and notice what you forget. There is always
something left behind, and it is always still billing.

## Afternoon - do it again properly

```bash
cd infra/aws
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan          # read this. every line. before you apply anything.
terraform apply
```

Then change exactly one variable - `db_instance_class` - and run `plan` again.
Read what it intends to do. **Does it replace the database or modify it in
place?** That question, asked before every apply, is the difference between a
routine change and an outage.

```bash
terraform destroy       # before you leave. every day. no exceptions.
```

## The three clouds

`infra/` has a parallel stack for AWS, GCP and Azure. Skim all three even if
you only apply one:

| Concept | AWS | GCP | Azure |
|---|---|---|---|
| Network | VPC | VPC | VNet |
| Run containers | ECS Fargate | Cloud Run | Container Apps |
| Managed Postgres | RDS | Cloud SQL | Flexible Server |
| Secrets | Secrets Manager | Secret Manager | Key Vault |

**The concepts are identical. Only the nouns change.** An intern who has
provisioned one can read the other two, and that transferability is worth more
than depth in any single provider.

## Chaos Hour - 16:00

```bash
./chaos/day2-drift.sh aws
```

Somebody changed a resource in the console behind your back. Terraform's state
and reality now disagree.

Run `terraform plan`. Then decide - and this is the actual exercise - which of
three responses is correct:

- `apply` — overwrite the manual change, Terraform wins
- `import` — adopt something created by hand into state
- `state rm` — forget something that was deleted by hand

There is no universally right answer. It depends on whether the manual change
was a mistake or a fix. Make them argue it.

## Skip this day and

You have infrastructure nobody can reproduce, nobody can review, and nobody can
rebuild after somebody deletes it.

## Before you leave

- [ ] `terraform destroy` has completed
- [ ] The console shows nothing left in the resource group / VPC
- [ ] A budget alert exists on the account
