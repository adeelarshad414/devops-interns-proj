# Day 5 - Kubernetes & Demo Day

> **Daig chapter:** One container is easy. Forty that find each other, restart
> themselves and survive a node dying — that is orchestration.

## Scope, stated honestly before you start

One day of Kubernetes buys you **four concepts**: deploy, scale, self-heal,
roll back.

No operators. No service mesh. No custom resources. No Helm charts you author.
You will not know Kubernetes this evening; you will know what it is for and
what to go and learn next. Anyone who tells you they learned Kubernetes in a
day is selling something.

## Morning - the four concepts

```bash
kubectl apply -k k8s/base
kubectl -n daig get pods -w
```

### 1. Deploy

Watch the state machine: `Pending` → `ContainerCreating` → `Running` →
`Ready`. Those are four different things and the difference matters — a pod can
be Running and never Ready, which is Demo Day scenario 4.

### 2. Scale

```bash
kubectl -n daig scale deploy/orders --replicas=5
kubectl -n daig get endpoints orders
```

Five pods, and the Service load-balances across them with no configuration
change anywhere. Compare that to Tuesday, when adding capacity meant editing
infrastructure.

### 3. Self-heal

```bash
kubectl -n daig delete pod <one-of-them>
kubectl -n daig get pods -w
```

It comes back in seconds with a new name. Nobody was paged. Nobody typed
anything. This is what Monday's manual container fix looks like once it is
automated — which is the through-line of the whole week.

### 4. Roll back

```bash
kubectl -n daig set image deploy/orders orders=ghcr.io/tkxel/daig-orders:v9-nope
kubectl -n daig rollout status deploy/orders     # it stalls
kubectl -n daig rollout undo deploy/orders
```

**The rollout stalls rather than completing.** `maxUnavailable: 0` plus a
readiness probe means the new pods never become Ready, so the old ones keep
serving. Traffic never moved.

That is the CrowdStrike lesson in Kubernetes form: the platform refused to
finish a bad deploy. Look at `k8s/base/orders.yaml` and find the two settings
that made it refuse.

## Afternoon - Demo Day

```bash
./chaos/day5-demoday.sh list
```

You own a Daig deployment in your own namespace. I break it in front of the
room. You get ten minutes and a microphone.

### Scoring

| Weight | Criterion |
|---|---|
| **40%** | **Diagnosis method** — did you read logs, metrics and traces, or restart things and hope? |
| 30% | The fix — does it work, and is it at the right layer? |
| 20% | Explanation — can you explain it to someone non-technical? |
| 10% | Composure when your first hypothesis is wrong |

**Diagnosis outweighs the fix deliberately.** A well-reasoned diagnosis that
runs out of time scores above a lucky guess that happens to work. Some of you
will not fix it in ten minutes; that is a normal outcome and it is survivable.
Restarting things at random is not.

### The method that works on all nine scenarios

```bash
kubectl -n <ns> get pods                      # what state, how many restarts?
kubectl -n <ns> describe pod <pod>            # read EVENTS at the bottom first
kubectl -n <ns> logs <pod> --previous         # what did the dead one say?
kubectl -n <ns> get endpoints <svc>           # empty endpoints = selector problem
kubectl -n <ns> get events --sort-by=.lastTimestamp
```

`describe` events and `logs --previous` solve most of the nine between them.
Learn to reach for those two before anything else.
