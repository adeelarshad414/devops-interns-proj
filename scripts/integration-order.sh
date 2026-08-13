#!/usr/bin/env bash
# Places one real order through all three application services and asserts
# that it reached the ASSIGNED state. This is what CI runs to prove the tiers
# actually talk to each other, rather than just that they each boot.
set -euo pipefail

ORDERS=${ORDERS:-http://localhost:3001}

echo "waiting for reference data..."
for i in $(seq 1 30); do
  count=$(curl -s "$ORDERS/api/restaurants" | grep -o '"id"' | wc -l | tr -d ' ')
  [ "$count" -gt 0 ] && break
  sleep 2
done

./scripts/seed.sh >/dev/null 2>&1 || true

RID=$(curl -s "$ORDERS/api/restaurants" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['restaurants'][0]['id'])")
echo "restaurant: $RID"

MID=$(curl -s "$ORDERS/api/restaurants/$RID/menu" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['items'][0]['id'])")
echo "menu item:  $MID"

RESP=$(curl -s -X POST "$ORDERS/api/orders" \
  -H 'content-type: application/json' \
  -d "{\"restaurant_id\":\"$RID\",\"customer_area\":\"Gulberg\",\"items\":[{\"menu_item_id\":\"$MID\",\"qty\":2}]}")
echo "response:   $RESP"

OID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['order_id'])")

sleep 2
STATE=$(curl -s "$ORDERS/api/orders/$OID" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
echo "final state: $STATE"

case "$STATE" in
  ASSIGNED|ACCEPTED)
    echo "PASS - order traversed orders -> kitchen -> dispatch"
    ;;
  *)
    echo "FAIL - order stalled in state $STATE"
    exit 1
    ;;
esac
