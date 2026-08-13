# Ansible - Day 3 morning

Configuration management, taught in the order that makes it land.

## Why this is here at all, said honestly to interns

Ansible is on the syllabus for two reasons. First, you will meet it - a large
amount of running infrastructure is configured this way and somebody has to
maintain it. Second, *configuration management as an idea* outlives its tools.

Tell them the state of the market plainly: **Chef and Puppet are legacy in
2026.** Chef went to Progress in 2020, Puppet to Perforce in 2022. They will
see both names on job descriptions and should know where they sit rather than
being quietly confused.

## The exercise that teaches idempotency

Do not explain idempotency. Have them run this:

```bash
ansible-playbook -i inventories/dev/hosts.yml site.yml     # lots of "changed"
ansible-playbook -i inventories/dev/hosts.yml site.yml     # all "ok"
```

Then ask what happened between the two runs. They will work it out, and having
worked it out they will remember it. Explaining first spends the lesson.

## Then the point that kills the whole approach

After the playbook works, ask: *what happens if someone SSHes in and changes
something by hand?* Nothing catches it until the next run. Then ask what a
container does about that problem.

That question is the bridge to Wednesday afternoon. Configuration management
converges a mutable box; containers make the box immutable so there is nothing
to converge. Teaching them in that order is why the second half of the day
feels like a relief rather than another tool.

## What the `daig_app` role deploys

The systemd unit runs `docker compose up` in `{{ daig_app_dir }}`, so the role
templates a `docker-compose.yml` there (previously missing — the unit would have
failed with "no configuration file"). Unlike the repo's root compose, the host
version **pulls** immutably-tagged images from the registry (`daig_registry` /
`daig_image_tag`) rather than building — there is no build context on a real
host. Postgres is external (the `postgres` role / `DATABASE_URL`); redis is
co-located as a cache. The `docker` role also creates `/etc/apt/keyrings` before
writing the Docker key and derives the apt `arch` from the host, so it works on
arm64 as well as amd64.
