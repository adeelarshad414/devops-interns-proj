#!/usr/bin/env bash
# OpenBao / Vault: the right answer to the secrets problem.
#
# Everything else in this repo uses CHANGE_ME_DEV_ONLY placeholders with a
# startup guard. That is a compromise for teaching. This script shows what
# production actually does, so interns see both and understand the difference
# rather than learning the compromise as the standard.
set -euo pipefail

export BAO_ADDR=${BAO_ADDR:-http://localhost:8200}
export BAO_TOKEN=${BAO_TOKEN:-CHANGE_ME_DEV_ONLY}
BAO="docker compose exec -T -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN=$BAO_TOKEN openbao bao"

hr() { printf '\n\033[1m=== %s ===\033[0m\n' "$1"; }

hr "1. Static secrets - the obvious part"
$BAO secrets enable -path=daig kv-v2 2>/dev/null || true
$BAO kv put daig/database \
  username=daig \
  password="$(openssl rand -base64 24)" \
  host=postgres
$BAO kv get daig/database

hr "2. Versioning - secrets have history"
$BAO kv put daig/database password="$(openssl rand -base64 24)" \
  username=daig host=postgres
$BAO kv get -version=1 daig/database
echo "Two versions. A bad rotation is now recoverable, which is the difference"
echo "between rotating secrets and being afraid to rotate secrets."

hr "3. Policies - least privilege, written down"
$BAO policy write daig-orders - <<'POLICY'
# The orders service may read its own database credentials. Nothing else.
path "daig/data/database" {
  capabilities = ["read"]
}
path "daig/data/payment" {
  capabilities = ["deny"]
}
POLICY
$BAO policy read daig-orders

hr "4. Dynamic database credentials - the part that changes how you think"
# This is the idea worth the whole session: instead of a long-lived password
# shared by every instance, Vault CREATES a database user per request with a
# TTL. A leaked credential expires on its own. A compromised service can be cut
# off by revoking one lease rather than rotating a password everywhere.
$BAO secrets enable database 2>/dev/null || true
$BAO write daig-db/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="orders" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/daig?sslmode=disable" \
  username="daig" password="CHANGE_ME_DEV_ONLY" 2>/dev/null \
  || echo "  (needs the database secrets engine mounted at daig-db - see the docs)"

cat <<'NOTE'

  A dynamic credential with a 1-hour TTL changes the threat model:
    - a leaked credential expires by itself
    - revocation is one lease, not a password change across every service
    - every connection is attributable to a specific lease
  Ask the room what a 1-hour TTL does to an attacker who exfiltrates a .env file.

NOTE

hr "5. Why -dev mode is not production"
$BAO status
echo
echo "-dev mode: in-memory storage, auto-unseal, root token on the command line."
echo "Production: persistent storage, Shamir or auto-unseal with a cloud KMS,"
echo "no root token in normal use, audit device enabled, TLS."
echo "Knowing WHY -dev is unsuitable is the actual learning outcome here."
