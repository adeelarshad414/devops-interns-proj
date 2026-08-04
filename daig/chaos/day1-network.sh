#!/usr/bin/env bash
# DAY 1 CHAOS - Linux and networking.
# Orders cannot reach the database. Three teams, three different causes.
#
#   ./chaos/day1-network.sh break 1   # DNS
#   ./chaos/day1-network.sh break 2   # firewall / packet drop
#   ./chaos/day1-network.sh break 3   # wrong port
#   ./chaos/day1-network.sh fix
#
# INSTRUCTOR: do not tell them which number they got.
set -euo pipefail
ACTION=${1:-help}
VARIANT=${2:-1}

case "$ACTION" in
  break)
    case "$VARIANT" in
      1)
        echo "[chaos] variant 1 applied"
        # Poison the hostname inside the orders container.
        docker compose exec -u root orders sh -c \
          "echo '10.255.255.1 postgres' >> /etc/hosts"
        docker compose restart orders
        ;;
      2)
        echo "[chaos] variant 2 applied"
        # Drop outbound packets to 5432. Requires NET_ADMIN.
        docker compose exec -u root --privileged orders sh -c \
          "apk add --no-cache iptables >/dev/null 2>&1 || true; \
           iptables -A OUTPUT -p tcp --dport 5432 -j DROP" \
          || echo "[chaos] iptables unavailable - falling back to variant 3"
        ;;
      3)
        echo "[chaos] variant 3 applied"
        # Point the connection string at a port nothing is listening on.
        docker compose stop orders >/dev/null
        docker compose run -d --name daig-orders-broken \
          -e DATABASE_URL='postgresql://daig:CHANGE_ME_DEV_ONLY@postgres:5433/daig' \
          orders
        ;;
      *) echo "unknown variant: $VARIANT"; exit 1 ;;
    esac
    echo "[chaos] symptom: orders /readyz returns 503. Cause is for them to find."
    echo "[chaos] hint chain: curl -> logs -> getent hosts -> ss -tlnp -> nc -zv"
    ;;
  fix)
    docker rm -f daig-orders-broken >/dev/null 2>&1 || true
    docker compose up -d --force-recreate orders
    echo "[chaos] reverted"
    ;;
  *)
    sed -n '2,12p' "$0"
    ;;
esac
