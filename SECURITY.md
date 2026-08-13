# Security policy

## This repository contains deliberate vulnerabilities

Daig is a teaching artifact. `services/orders/src/insecure.js` contains six
intentional vulnerabilities, and several other files contain deliberate
misconfigurations. They are documented in the README and in
`docs/DEVSECOPS.md`.

**Do not report these as vulnerabilities.** They are the curriculum.

They are gated behind `INSECURE_MODE=true`, and the module exits 78 rather than
loading when `NODE_ENV=production`.

## Never deploy this

Daig is not production software and has no path to becoming production software.
It has no authentication, plaintext transport by default, and a deliberately
weak security posture in several places.

## Reporting something real

If you find a vulnerability that is **not** in the documented list — particularly
anything that could harm someone running the training environment locally — open
a private security advisory through GitHub, or email the maintainer directly.

Please do not open a public issue for a real finding.

## Deliberate defects, for reference

| Location | Defect | Documented in |
|---|---|---|
| `services/orders/src/insecure.js` | Six vulnerabilities, CWE-tagged | `docs/DEVSECOPS.md` |
| `infra/aws/loadbalancer.tf` | No TLS on the ALB | TODO comment in file |
| `k8s/base/secret.yaml` | Inline `stringData` | Comment in file |
| `db/init/001_schema.sql` | Two indexes commented out | Day 4 exercise |
| `docker-compose.yml` | Database port published to the host | Day 3 exercise |
| `vault/.init-keys.json` | All 5 unseal keys in one file | `vault/README.md` |

Every one of these is deliberate, labelled in place, and exists so that a scanner
has something true to find.

## Credentials

Every placeholder in this repository is the literal string
`CHANGE_ME_DEV_ONLY`, registered in `DUMMY-VALUES.md`. A CI job fails the build
if one appears outside its allowed files.

If you find anything that looks like a real credential, treat it as an incident:
report it privately, and assume it is compromised regardless of how briefly it
was committed. Git history is forever.
