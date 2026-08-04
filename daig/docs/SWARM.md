# Docker Swarm - Day 5 morning, before Kubernetes

## Why Swarm is on the syllabus

Swarm teaches the four orchestration ideas in forty lines of readable YAML:

1. **Desired state** — you declare 3 replicas; something else keeps them at 3
2. **Service discovery** — `http://kitchen:3002` resolves, with no config
3. **Rolling updates** — one task at a time, with automatic rollback
4. **Self-healing** — kill a task and it comes back

Teach those four with Swarm in ninety minutes, *then* open Kubernetes, and
Kubernetes stops looking arbitrary. Every concept has a Swarm equivalent they
already hold in their heads.

## Then be honest about it

Swarm is in maintenance. The industry standardised on Kubernetes. **Nobody
should start a new production platform on Swarm in 2026.**

Say that plainly. Interns who learn Swarm and then discover on their own that
it is not where the jobs are will reasonably wonder what else you oversold.
Framing it as a deliberate teaching ladder costs nothing and buys trust.

## The lab

```bash
docker swarm init

# Secrets first - Swarm has real secret management, unlike plain Compose.
printf 'CHANGE_ME_DEV_ONLY' | docker secret create db_password -
printf 'postgresql://daig:CHANGE_ME_DEV_ONLY@postgres:5432/daig' \
  | docker secret create database_url -

docker stack deploy -c swarm/daig-stack.yml daig
docker stack services daig
docker service ps daig_orders
```

### Exercise 1 — desired state

```bash
docker service scale daig_orders=6
docker service ps daig_orders          # six tasks
docker rm -f $(docker ps -q --filter name=daig_orders | head -1)
docker service ps daig_orders          # back to six, one with a new id
```

Nobody typed a recovery command. That gap between "what I asked for" and "what
is running" being continuously reconciled *is* orchestration.

### Exercise 2 — rolling update and rollback

```bash
docker service update --image ghcr.io/adeelarshad414/daig/orders:v2 daig_orders
docker service ps daig_orders          # watch tasks replaced one at a time

# now a deliberately broken image
docker service update --image ghcr.io/adeelarshad414/daig/orders:does-not-exist daig_orders
docker service ps daig_orders          # failure_action: rollback kicks in
```

The rollback happens because of `failure_action: rollback` and `monitor: 30s`
in the stack file. Find those lines. This is the CrowdStrike lesson again, on a
third platform.

### Exercise 3 — the routing mesh

On a multi-node swarm, curl port 8080 on a node that is *not* running a `web`
task. It works. Ask why before explaining.

### Exercise 4 — network isolation

```bash
docker network inspect daig_data | grep -i internal
```

The `data` network is `internal: true`. The `web` service is not attached to it
at all. Try to reach postgres from a web task and fail. **The topology enforces
the three-tier model** rather than relying on anyone remembering it.

## Swarm to Kubernetes, term by term

Hand this out when you switch. It converts the afternoon from new material into
translation.

| Swarm | Kubernetes |
|---|---|
| service | Deployment + Service |
| task | Pod |
| `replicas: 3` | `spec.replicas: 3` |
| overlay network | ClusterIP + NetworkPolicy |
| `docker service scale` | `kubectl scale` |
| `update_config` | `strategy.rollingUpdate` |
| `failure_action: rollback` | readiness probe + `maxUnavailable: 0` |
| secret | Secret (+ a real secrets operator) |
| routing mesh | Service + kube-proxy |
| `docker stack deploy` | `kubectl apply -k` |
| manager / worker | control plane / node |

## Clean up

```bash
docker stack rm daig
docker swarm leave --force
```
