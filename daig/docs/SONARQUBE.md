# SonarQube - code quality as a gate

Slots into **Day 4 morning**, alongside CI/CD. It belongs there because it is
the same idea as a failing test: an automated check with the authority to stop
a release.

## Start it

```bash
docker compose -f docker-compose.yml -f docker-compose.sonar.yml up -d
# wait 2-4 minutes, then http://localhost:9000  (admin / admin)
```

If the container dies on boot, it is almost always the kernel mmap limit that
Elasticsearch needs:

```bash
sudo sysctl -w vm.max_map_count=524288
```

That is itself a good Day 1 callback — a container failing for a reason that
lives on the host, not in the image.

## Scan Daig

```bash
docker run --rm --network daig_default \
  -v "$PWD:/usr/src" \
  -e SONAR_HOST_URL=http://sonarqube:9000 \
  -e SONAR_TOKEN=<generate one in My Account > Security> \
  sonarsource/sonar-scanner-cli
```

## What it will find, and what to do about it

Daig contains real, deliberate quality problems. Sonar will flag them, which
makes it a much better teaching target than a clean codebase:

| Finding | Where | The interesting part |
|---|---|---|
| Cognitive complexity | `computeSurgeScore()` in kitchen | Sonar flags the *shape*, the profiler flags the *cost*. Two tools, two different truths about the same function. |
| Duplicated blocks | probe handlers across three services | Real duplication. Ask whether extracting it is worth the coupling. Sometimes the answer is no. |
| Hardcoded credentials | `CHANGE_ME_DEV_ONLY` strings | Sonar is right to flag them. Explain the registered-dummy discipline and why the CI job greps for strays. |
| Missing coverage | most of the codebase | Do not chase the number. See below. |

## The two things worth arguing about

**1. Coverage is a proxy, not a goal.** 80% coverage of trivial getters is
worse than 40% coverage of the order state machine. Ask the room which they
would rather have. There is a right answer and it is not the bigger number.

**2. New code versus overall.** Set the quality gate on **new code only**.
Holding a legacy codebase to a green overall score means either nobody ever
merges anything or somebody games the metric. Holding *new* code to a high
standard is strict and achievable at the same time, which is the only kind of
standard that survives contact with a deadline.

## CI wiring

`.github/workflows/quality.yml` runs the scan on every pull request and blocks
the merge when the gate fails. Requires two repository secrets: `SONAR_TOKEN`
and `SONAR_HOST_URL`.
