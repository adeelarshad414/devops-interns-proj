# OpenBao — credential storage

## What and why

[OpenBao](https://openbao.org) is the Linux Foundation fork of HashiCorp Vault,
created when Vault moved to the BUSL licence. Same API, same CLI verbs, Mozilla
Public Licence. **Everything here works unchanged against Vault**, so nothing
learned is wasted if your employer runs the original.

Daig uses it to answer one question honestly: *where do credentials actually
live?* Every other part of this repository uses `CHANGE_ME_DEV_ONLY` placeholders
with a startup guard. That is a teaching compromise. This is the real answer, and
interns should see both so they know which is which.

## Run it

```bash
make vault-up        # start OpenBao, initialise, unseal, provision
make vault-app       # run Daig with credentials from OpenBao
make vault-demo      # the guided walkthrough
make vault-ui        # browser UI; root token is in vault/.init-keys.json
```

Confirm the services actually used it:

```bash
docker compose logs orders | grep credential_source
# {"level":"info","msg":"configuration resolved","credential_source":"openbao"}
```

If that says `environment`, the integration is not working and the log will say
why. The loader deliberately refuses to fall back silently.

## Not dev mode, on purpose

`bao server -dev` is one command and teaches the wrong lifecycle: in-memory
storage, auto-unseal, a root token printed to the terminal. Interns come away
thinking a vault is a key-value store with extra steps.

This runs with file storage and a real seal, so they see the actual sequence:

```
initialise  ->  unseal  ->  authenticate  ->  read
   once        every restart    per service    per secret
```

`vault/bootstrap.sh` walks that sequence with commentary at each step.

## Shamir's Secret Sharing

Initialisation generates **5 key shares with a threshold of 3**. Any three
reconstruct the master key; any two are useless.

The reason this exists: nobody should be able to unseal the vault alone. In
production those five shares go to five different people, or the vault
auto-unseals from a cloud KMS so no human holds a share at all.

`vault/.init-keys.json` holds all five plus the root token, which is
catastrophic and correct for a training environment. It is gitignored. Say out
loud that this file existing in one place is the thing production designs around.

## AppRole, and why not a token

A token in an environment variable is precisely the problem a vault is meant to
solve. AppRole splits the credential:

| | `role_id` | `secret_id` |
|---|---|---|
| Secret? | No | **Yes** |
| Lifetime | Permanent | 24h here |
| Where it lives | Configuration, image, IaC | Delivered separately at deploy time |

Compromising one gets you nothing. In production the `secret_id` is delivered by
a trusted orchestrator — a Kubernetes service account, an EC2 instance identity,
a CI OIDC token — so it never sits in a file at all.

## Least privilege, demonstrated rather than described

Four policies in `vault/policies/`. The interesting one is what each service
**cannot** read:

| Service | Reads | Explicitly denied |
|---|---|---|
| orders | `daig/database`, `daig/app` | `daig/payment`, all of `sys/` |
| kitchen | `daig/database` | `daig/app`, `daig/payment` |
| dispatch | `daig/database` | `daig/app`, `daig/payment` |
| intern-readonly | secret *metadata* only | every secret *value* |

`bootstrap.sh` finishes by logging in as `orders` and attempting a read it is not
allowed, so interns watch the denial happen. **A control you have never seen fire
is not a control you trust.**

The `intern-readonly` policy is worth pointing at: engineers need to know what
secrets exist and when they were last rotated far more often than they need the
values. Most production policies look like this.

## The idea that changes how they think: dynamic credentials

```bash
BAO_DYNAMIC_DB=true make vault-app
```

Instead of one long-lived password shared by every instance, OpenBao **creates a
PostgreSQL user per request** with a TTL. Consequences:

- A leaked credential expires by itself.
- Revocation is one lease, not a password rotation across every service.
- Every connection is attributable to a specific lease.

Then ask the room: *what does a one-hour TTL do to an attacker who exfiltrates a
`.env` file at 09:00 and gets around to using it at 14:00?*

That question does more work than an hour of explanation.

## Audit logging

Enabled in step 3 of bootstrap — **before any secret is written**. An audit log
that starts after the interesting event is not an audit log.

```bash
docker compose -f docker-compose.yml -f docker-compose.vault.yml \
  exec openbao tail -5 /openbao/logs/audit.log
```

Every read, with a timestamp and an identity. This is the difference between "who
read the production database password, and when" being an unbounded investigation
and being a `grep`.

## In-app or sidecar

Two ways to get a secret into a service. Daig ships the first wired up and the
second configured but disabled, so they can be compared:

| | In-app (`services/_shared/secrets.js`) | Agent sidecar (`vault/agent/`) |
|---|---|---|
| App changes | Yes | **None** |
| Rotation | App can react immediately | Needs a restart or a file watcher |
| Works with closed-source apps | No | **Yes** |
| Extra process | No | Yes, one per service |
| Vault as a dependency | **Hard** — no vault, no start | Soft — the agent caches |

Ask which they would pick for a legacy Java service they cannot modify. The
answer is obvious once framed that way, and arriving at it themselves is worth
more than being told.

## What is different in production

| Here | Production |
|---|---|
| `storage "file"` | `raft` with 3 or 5 nodes, or a supported backend |
| `tls_disable = true` | Real certificates. Never plaintext. |
| Manual unseal from a file | Auto-unseal via cloud KMS, or 3 humans |
| Root token in `.init-keys.json` | Root token revoked after setup; admin access via OIDC |
| `secret_id` in a file | Delivered by Kubernetes SA / instance identity / CI OIDC |
| Audit to a local file | Shipped to a separate, append-only system |

Interns should be able to name every row of that table by the end of the session.
Knowing *why* the left column is unacceptable is the actual learning outcome.

## Files

```
vault/
├── config/config.hcl              server config, annotated with production deltas
├── policies/*.hcl                 four least-privilege policies
├── agent/agent.hcl                sidecar alternative
├── agent/templates/daig.env.ctmpl the rendered credential file
├── bootstrap.sh                   init, unseal, provision, verify
├── demo.sh                        guided walkthrough
├── .init-keys.json                GITIGNORED. unseal keys + root token.
└── .approle/*.env                 GITIGNORED. per-service role_id + secret_id.
```
