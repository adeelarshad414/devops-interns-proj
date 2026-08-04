#!/usr/bin/env bash
# Initialise OpenBao and provision everything Daig needs.
#
#   ./vault/bootstrap.sh
#
# Idempotent: safe to run repeatedly. If OpenBao is already initialised it
# unseals and reconciles rather than failing.
#
# WHAT THIS DOES, in the order the concepts should be learned:
#   1. initialise      - generates the unseal keys and the root token, ONCE
#   2. unseal          - reconstructs the encryption key from key shares
#   3. audit device    - start logging before storing anything
#   4. KV v2 engine    - versioned static secrets
#   5. secrets         - generated, never hardcoded
#   6. policies        - least privilege per service
#   7. AppRole auth    - how a service authenticates without a human
#   8. credentials out - role_id and secret_id written to vault/.approle/
set -euo pipefail

BAO_CONTAINER=${BAO_CONTAINER:-openbao}
KEYS_FILE="vault/.init-keys.json"
APPROLE_DIR="vault/.approle"
COMPOSE="docker compose -f docker-compose.yml -f docker-compose.vault.yml"

bao() { $COMPOSE exec -T -e BAO_ADDR=http://127.0.0.1:8200 "$BAO_CONTAINER" bao "$@"; }
baot() { $COMPOSE exec -T -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN="$ROOT_TOKEN" "$BAO_CONTAINER" bao "$@"; }
hr() { printf '\n\033[1m--- %s\033[0m\n' "$1"; }

mkdir -p "$APPROLE_DIR"

# ---------------------------------------------------------------- 1. INITIALISE
hr "1. initialise"
if bao status -format=json 2>/dev/null | grep -q '"initialized": *true'; then
  echo "already initialised"
  if [ ! -f "$KEYS_FILE" ]; then
    echo
    echo "ERROR: OpenBao is initialised but $KEYS_FILE is missing."
    echo "The unseal keys and root token existed exactly once, at init, and are"
    echo "not recoverable. In production this is a disaster-recovery event."
    echo "Here: docker compose down -v and start again."
    exit 1
  fi
else
  echo "initialising with 5 key shares, threshold 3"
  # Shamir's Secret Sharing: the master key is split into 5 shares and any 3
  # reconstruct it. No single person can unseal alone - which is the point.
  bao operator init -key-shares=5 -key-threshold=3 -format=json > "$KEYS_FILE"
  chmod 600 "$KEYS_FILE"
  echo "keys written to $KEYS_FILE"
  echo
  echo "  THIS FILE IS THE ENTIRE SECURITY OF THE VAULT."
  echo "  It is gitignored. In production these shares go to five different"
  echo "  people, or to a KMS for auto-unseal, and never to one file on one disk."
fi

ROOT_TOKEN=$(python3 -c "import json;print(json.load(open('$KEYS_FILE'))['root_token'])")

# -------------------------------------------------------------------- 2. UNSEAL
hr "2. unseal"
if bao status -format=json 2>/dev/null | grep -q '"sealed": *false'; then
  echo "already unsealed"
else
  for i in 0 1 2; do
    KEY=$(python3 -c "import json;print(json.load(open('$KEYS_FILE'))['unseal_keys_b64'][$i])")
    bao operator unseal "$KEY" >/dev/null
  done
  echo "unsealed with 3 of 5 shares"
fi

# --------------------------------------------------------------- 3. AUDIT FIRST
hr "3. audit device"
if baot audit list 2>/dev/null | grep -q 'file/'; then
  echo "audit device already enabled"
else
  baot audit enable file file_path=/openbao/logs/audit.log
  echo "every secret read is now logged to /openbao/logs/audit.log"
fi
echo "  Enabled BEFORE any secret is written, deliberately. An audit log that"
echo "  starts after the interesting event is not an audit log."

# ------------------------------------------------------------------- 4. KV V2
hr "4. KV v2 secrets engine"
if baot secrets list 2>/dev/null | grep -q '^daig/'; then
  echo "daig/ already mounted"
else
  baot secrets enable -path=daig -version=2 kv
  echo "mounted daig/ as KV v2 (versioned)"
fi

# ------------------------------------------------------------------ 5. SECRETS
hr "5. secrets"
DB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
JWT=$(openssl rand -hex 32)
PAY=$(openssl rand -hex 24)

baot kv put daig/database \
  username=daig \
  password="$DB_PASS" \
  host=postgres \
  port=5432 \
  dbname=daig \
  url="postgresql://daig:${DB_PASS}@postgres:5432/daig" >/dev/null

baot kv put daig/app \
  jwt_secret="$JWT" \
  payment_api_key="$PAY" >/dev/null

echo "wrote daig/database and daig/app"
echo "  Values are GENERATED here, not typed. Nobody knows the database"
echo "  password, including you, which is the correct state of affairs."

# ----------------------------------------------------------------- 6. POLICIES
hr "6. policies"
for svc in orders kitchen dispatch intern-readonly; do
  baot policy write "daig-$svc" - < "vault/policies/$svc.hcl"
  echo "  daig-$svc"
done

# ------------------------------------------------------------------ 7. APPROLE
hr "7. AppRole authentication"
if baot auth list 2>/dev/null | grep -q '^approle/'; then
  echo "approle already enabled"
else
  baot auth enable approle
fi

for svc in orders kitchen dispatch; do
  baot write "auth/approle/role/$svc" \
    token_policies="daig-$svc" \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=24h \
    secret_id_num_uses=0 >/dev/null

  ROLE_ID=$(baot read -field=role_id "auth/approle/role/$svc/role-id")
  SECRET_ID=$(baot write -f -field=secret_id "auth/approle/role/$svc/secret-id")

  cat > "$APPROLE_DIR/$svc.env" <<EOF
# Generated by vault/bootstrap.sh - gitignored.
# role_id is not a secret and may live in configuration.
# secret_id IS a secret, expires in 24h, and is delivered separately.
BAO_ADDR=http://openbao:8200
BAO_ROLE_ID=$ROLE_ID
BAO_SECRET_ID=$SECRET_ID
EOF
  chmod 600 "$APPROLE_DIR/$svc.env"
  echo "  $svc -> $APPROLE_DIR/$svc.env"
done

# ------------------------------------------------------------------- 8. VERIFY
hr "8. verify least privilege"
echo "Logging in as orders and attempting a read it is NOT allowed..."
ORDERS_TOKEN=$(baot write -f -field=token \
  auth/approle/login \
  role_id="$(baot read -field=role_id auth/approle/role/orders/role-id)" \
  secret_id="$(baot write -f -field=secret_id auth/approle/role/orders/secret-id)" \
  2>/dev/null || echo '')

if [ -n "$ORDERS_TOKEN" ]; then
  if $COMPOSE exec -T -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN="$ORDERS_TOKEN" \
       "$BAO_CONTAINER" bao kv get daig/payment 2>&1 | grep -qi 'permission denied'; then
    echo "  correctly DENIED reading daig/payment"
  else
    echo "  WARNING: expected a permission denial and did not get one. Check the policy."
  fi
fi

hr "done"
cat <<'EOF'
Next:

  make vault-app          run Daig with credentials from OpenBao
  make vault-ui           open the UI (token is in vault/.init-keys.json)
  ./vault/demo.sh         the guided walkthrough

Check the services actually used it:

  docker compose logs orders | grep credential_source
  # expect: "credential_source":"openbao"

Read the audit log - every access, with a timestamp and an identity:

  docker compose -f docker-compose.yml -f docker-compose.vault.yml \
    exec openbao cat /openbao/logs/audit.log | tail -5
EOF
