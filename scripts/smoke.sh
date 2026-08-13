#!/usr/bin/env bash
# Verifies every tier answers. Used locally and in CI.
set -euo pipefail

WEB=${WEB:-http://localhost:8080}
ORDERS=${ORDERS:-http://localhost:3001}
KITCHEN=${KITCHEN:-http://localhost:3002}
DISPATCH=${DISPATCH:-http://localhost:3003}

fail=0

check() {
  local name=$1 url=$2 expect=${3:-200}
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" || echo 000)
  if [ "$code" = "$expect" ]; then
    printf '  %-28s %s\n' "$name" "OK ($code)"
  else
    printf '  %-28s %s\n' "$name" "FAIL (got $code, wanted $expect)"
    fail=1
  fi
}

echo "TIER 1 - presentation"
check "web /healthz"          "$WEB/healthz"
check "web serves index"      "$WEB/"

echo "TIER 2 - application"
check "orders /healthz"       "$ORDERS/healthz"
check "orders /readyz"        "$ORDERS/readyz"
check "orders /metrics"       "$ORDERS/metrics"
check "kitchen /healthz"      "$KITCHEN/healthz"
check "kitchen /readyz"       "$KITCHEN/readyz"
check "dispatch /healthz"     "$DISPATCH/healthz"
check "dispatch /readyz"      "$DISPATCH/readyz"

echo "TIER 3 - data (reached through readiness probes above)"
check "orders sees database"  "$ORDERS/readyz"

echo
if [ "$fail" -eq 0 ]; then
  echo "all tiers healthy"
else
  echo "SMOKE TEST FAILED"
  exit 1
fi
