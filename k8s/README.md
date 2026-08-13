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
| Scale | `kubectl -n daig get hpa` then drive load with `load/iftar-spike.js` | the HPA raises replicas as CPU climbs; the Service load-balances without any change |
| Self-heal | `kubectl -n daig delete pod <one>` | it comes back in seconds, with a new name |
| Roll back | `kubectl -n daig set image deploy/orders orders=...:bad` then `rollout undo` | traffic never fully shifts because the readiness probe fails |

> **On scaling:** every application Deployment is now owned by a
> HorizontalPodAutoscaler, so `kubectl scale` is reconciled straight back by the
> HPA within a scrape interval. That is the point — show them the manual scale
> being overridden, then scale for real by generating load. (The commit that
> added HPAs also removed the static `replicas:` field; declaring both is what
> makes an autoscaler thrash.)

That last one is the CrowdStrike lesson in Kubernetes form: the rollout stalls
because the new pods never become Ready, so the old ones keep serving. The
platform refused to complete a bad deploy. Point at it explicitly.

## Secrets

`base/secret.yaml` uses `stringData` with registered dummies so it is readable
and teachable. **This is not how you do it in production.** In production:
External Secrets Operator, Sealed Secrets, or the cloud provider's CSI driver,
pulling from Secrets Manager / Secret Manager / Key Vault. Say this out loud -
a committed Secret manifest is exactly the habit you do not want them forming.

## Production posture baked into `base/`

The manifests carry the baseline a real cluster would expect, so the four
exercises run against something honest rather than a toy:

- **Images pinned** to an immutable tag (`kustomization.yaml`), never `:latest` —
  otherwise `rollout undo` has nothing distinct to roll back to.
- **`networkpolicy.yaml`** — default-deny plus explicit tier allows (web → app →
  data). NB: only a policy-aware CNI (Calico/Cilium) *enforces* this; kind's
  default CNI accepts but ignores it.
- **`hpa.yaml`** — an HPA per application service; Deployments set no static
  `replicas`.
- **Pod hardening** — non-root + dropped capabilities + seccomp on the app tier;
  `automountServiceAccountToken: false`; `topologySpreadConstraints`; a PDB per
  workload. `redis` is a StatefulSet with a PVC (a Deployment silently lost data
  on reschedule).
- **Namespace Pod Security Admission** — `baseline` enforced, `restricted`
  warn+audit. Tighten `enforce` to `restricted` once every image runs rootless.

`web` is still a raw `LoadBalancer` for a controller-free demo cluster; the
comment in `web.yaml` points at the ClusterIP-plus-Ingress shape for real use.
