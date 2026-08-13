#!/usr/bin/env bash
# Guided walkthrough of OpenBao, in the order the ideas build.
# Run vault/bootstrap.sh first.
set -euo pipefail

COMPOSE="docker compose -f docker-compose.yml -f docker-compose.vault.yml"
ROOT_TOKEN=$(python3 -c "import json;print(json.load(open('vault/.init-keys.json'))['root_token'])")
bao() { $COMPOSE exec -T -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN="$ROOT_TOKEN" openbao bao "$@"; }

pause() { printf '\n\033[2m[enter to continue]\033[0m'; read -r _; }
hr() { printf '\n\033[1m=== %s\033[0m\n' "$1"; }

hr "1. Versioning - secrets have history"
bao kv get daig/database
echo
echo "Rotating the password..."
NEW=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
bao kv put daig/database username=daig password="$NEW" host=postgres port=5432 \
  dbname=daig url="postgresql://daig:${NEW}@postgres:5432/daig" >/dev/null
bao kv metadata get daig/database
echo
echo "Two versions now. A bad rotation is recoverable, which is the difference"
echo "between rotating secrets and being afraid to rotate secrets."
pause

hr "2. Rollback"
bao kv rollback -version=1 daig/database
echo "Back to version 1. Note it creates version 3 rather than deleting 2 -"
echo "the history is append-only, like the order_events table in our schema."
pause

hr "3. Least privilege - what a compromised service can reach"
ROLE_ID=$(bao read -field=role_id auth/approle/role/dispatch/role-id)
SECRET_ID=$(bao write -f -field=secret_id auth/approle/role/dispatch/secret-id)
TOKEN=$(bao write -f -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")

echo "Logged in as dispatch. Reading daig/database (allowed):"
$COMPOSE exec -T -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN="$TOKEN" \
  openbao bao kv get -field=host daig/database && echo "  -> allowed"

echo
echo "Now reading daig/app (denied by policy):"
$COMPOSE exec -T -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN="$TOKEN" \
  openbao bao kv get daig/app 2>&1 | tail -2

echo
echo "That denial is the whole point. If dispatch is compromised, the attacker"
echo "gets a database host and nothing else - not the JWT signing key, not the"
echo "payment provider credentials."
pause

hr "4. Token TTL - credentials that expire"
$COMPOSE exec -T -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN="$TOKEN" \
  openbao bao token lookup -format=json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin)['data']; print(f\"  ttl: {d['ttl']}s  renewable: {d['renewable']}  policies: {d['policies']}\")" \
  || echo "  (lookup unavailable)"
echo
echo "One hour. Ask the room: what does a 1-hour TTL do to an attacker who"
echo "exfiltrates this token at 09:00 and gets around to using it at 14:00?"
pause

hr "5. The audit log"
$COMPOSE exec -T openbao sh -c 'tail -3 /openbao/logs/audit.log' 2>/dev/null \
  | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        e = json.loads(line)
        print(f\"  {e.get('time','')} {e.get('type','')} \"
              f\"{e.get('request',{}).get('operation','')} \"
              f\"{e.get('request',{}).get('path','')}\")
    except Exception:
        pass
" || echo "  (no audit entries yet)"
echo
echo "Every read, with a timestamp and an identity. This is the answer to"
echo "'who read the production database password, and when'. Without it that"
echo "question is an unbounded investigation; with it, it is a grep."
pause

hr "6. Seal it"
echo "Sealing throws away the in-memory encryption key. Everything stops."
echo "It is the break-glass response to a suspected compromise:"
echo
echo "    bao operator seal"
echo
echo "Unsealing again needs 3 of the 5 key shares - so no single person can"
echo "bring it back alone. That is the same property that makes it safe."
echo
echo "Not doing it automatically here, because you would have to unseal to"
echo "carry on. Try it yourself when you are finished."
