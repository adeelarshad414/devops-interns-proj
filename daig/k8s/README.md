# Kubernetes - Day 5

Scope is deliberately four concepts and no more: **deploy, scale, self-heal,
roll back**. No operators, no service mesh, no CRDs, no Helm charts they author.

One day buys four ideas. Anyone who claims they learned Kubernetes in a day is
selling something, and interns should be told that plainly so they do not
overclaim in an interview.

## Apply order

```bash
kubectl apply -k k8s/base            # namespace, config, secret, data tier
kubectl -n daig rollout status deploy/orders
kubectl -n daig get pods -w
```

## The four exercises

| Concept | Command | What to watch |
|---|---|---|
| Deploy | `kubectl apply -k k8s/base` | pods go Pending -> ContainerCreating -> Running -> Ready |
| Scale | `kubectl -n daig scale deploy/orders --replicas=5` | new pods appear; the Service load-balances without any change |
| Self-heal | `kubectl -n daig delete pod <one>` | it comes back in seconds, with a new name |
| Roll back | `kubectl -n daig set image deploy/orders orders=...:bad` then `rollout undo` | traffic never fully shifts because the readiness probe fails |

That last one is the CrowdStrike lesson in Kubernetes form: the rollout stalls
because the new pods never become Ready, so the old ones keep serving. The
platform refused to complete a bad deploy. Point at it explicitly.

## Secrets

`base/secret.yaml` uses `stringData` with registered dummies so it is readable
and teachable. **This is not how you do it in production.** In production:
External Secrets Operator, Sealed Secrets, or the cloud provider's CSI driver,
pulling from Secrets Manager / Secret Manager / Key Vault. Say this out loud -
a committed Secret manifest is exactly the habit you do not want them forming.
