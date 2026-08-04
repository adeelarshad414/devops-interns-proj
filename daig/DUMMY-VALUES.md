# Registered dummy values

> **These are the fallback, not the design.** `vault/` runs OpenBao as the real
> credential store, and `services/_shared/secrets.js` prefers it. The placeholders
> below are what local development uses when no vault is configured — and a
> service refuses to start with them when `NODE_ENV=production`.
>
> Showing interns both, side by side, is the point. See `vault/README.md`.

Every placeholder secret in this repository uses the literal string
`CHANGE_ME_DEV_ONLY`. Each service runs a startup guard that **exits 78** if it
finds a registered dummy while `NODE_ENV=production`.

This is not theatre. It is the cheapest possible protection against the single
most common cause of credential leaks: a development default that quietly
survives into production.

| Key | Where | Real source in production |
|---|---|---|
| `POSTGRES_PASSWORD` | `.env.example`, `docker-compose.yml` | AWS Secrets Manager / GCP Secret Manager / Azure Key Vault |
| `JWT_SECRET` | `.env.example`, all three app services | as above |
| `GF_SECURITY_ADMIN_PASSWORD` | `docker-compose.obs.yml` | Grafana SSO in production; never a password |
| `PAYMENT_API_KEY` | `.env.example`, `orders` | payment provider dashboard |
| `REDIS_PASSWORD` | `.env.example` | secret store |
| `POSTGRES_PASSWORD` (sonar) | `docker-compose.sonar.yml` | secret store |
| `BAO_DEV_ROOT_TOKEN_ID` | `docker-compose.security.yml` | never exists in production - OpenBao uses Shamir or KMS auto-unseal |

## The guard

`services/_shared/secrets.js`, called before any service opens a port. (The
older `guard.js` is retained for its unit test and documents the same pattern.)

```js
if (process.env.NODE_ENV === 'production' && looksLikeDummy(value)) {
  console.error(`FATAL: registered dummy value in ${key} while NODE_ENV=production`);
  process.exit(78);   // EX_CONFIG
}
```

Exit code 78 is `EX_CONFIG` from `sysexits.h`. It means "the configuration is
wrong", which is precisely true and is distinguishable from a crash in your
orchestrator's restart logic.

## Rules

1. A new placeholder gets a row in this table in the same commit.
2. Never a plausible-looking fake. `hunter2` gets committed to production;
   `CHANGE_ME_DEV_ONLY` does not.
3. Never a real credential in this repository, including in a comment,
   including "temporarily", including in a branch you intend to delete.
