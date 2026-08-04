# Day 3 - Configuration Management & Containers

> **Daig chapter:** The box exists. Make it useful, then make the box
> irrelevant.

## Morning - Ansible

Do not read a definition of idempotency. Run this:

```bash
cd ansible
ansible-playbook -i inventories/dev/hosts.yml site.yml    # lots of "changed"
ansible-playbook -i inventories/dev/hosts.yml site.yml    # all "ok"
```

Now explain what happened between the two runs. You will remember the answer
because you worked it out.

Then the question that undermines the whole approach: **what happens if someone
SSHes in and changes something by hand?** Nothing catches it until the next
run. Hold that thought until after lunch.

### Honest note on the tools

Ansible is on the syllabus because you will meet it - a great deal of running
infrastructure is configured this way. You will also see **Chef and Puppet** on
job descriptions; both are legacy in 2026 (Chef went to Progress in 2020,
Puppet to Perforce in 2022). Know where they sit so you are not quietly
confused in an interview.

Configuration management *as an idea* outlives its tools. That is what you are
learning, not a product.

## Afternoon - Docker

```bash
cat services/orders/Dockerfile      # read it before you build it
docker build -f services/orders/Dockerfile -t daig-orders:mine .
docker images | grep daig           # how big? why?
docker compose up -d
```

Things to actually do, not just read about:

- **Layer caching.** Change one line of source, rebuild, watch which layers are
  reused. Then change `package.json` and watch the whole thing rebuild. That is
  why dependencies are copied before source.
- **Shrink the image.** Multi-stage build, `--omit=dev`, alpine base. Measure
  before and after.
- **Run as non-root.** The Dockerfiles already do. Find the line. Understand
  why `readOnlyRootFilesystem` needs that `/tmp` volume mount.
- **Answer the morning's question.** A container does not converge a mutable
  box; it replaces the box. There is nothing to drift.

That contrast is the whole point of teaching these two things on the same day,
in this order.

## Chaos Hour - 16:00

```bash
./chaos/day3-crashloop.sh break
```

Monday's crash loop returns, but now there are three possible causes and the
symptom is identical for all three:

1. Config **missing** — exits 78 instantly
2. Config **wrong** — starts, then fails readiness
3. Environment **wrong** — cannot bind the port

The fastest discriminator is the exit code:

```bash
docker inspect daig-chaos-orders --format '{{.State.ExitCode}} {{.State.Error}}'
docker logs daig-chaos-orders
```

Exit 78 means `EX_CONFIG` - the configuration is wrong. That is a *different
class of failure* from a crash, and knowing the difference saves you twenty
minutes on a real incident.

## Skip this day and

"Works on my machine", for the rest of your career.
