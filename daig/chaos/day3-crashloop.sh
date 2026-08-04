#!/usr/bin/env bash
# DAY 3 CHAOS - one symptom, three causes.
# A deliberate callback to the kickoff exercise. Same crash loop, but now they
# have the vocabulary to name what is happening.
#
#   ./chaos/day3-crashloop.sh break [1|2|3]
#   ./chaos/day3-crashloop.sh fix
set -euo pipefail
ACTION=${1:-help}
VARIANT=${2:-$((RANDOM % 3 + 1))}

case "$ACTION" in
  break)
    docker rm -f daig-chaos-orders >/dev/null 2>&1 || true
    NET=$(docker network ls --filter name=daig --format '{{.Name}}' | head -1)
    case "$VARIANT" in
      1) # missing config - exits 78 immediately
        docker run -d --name daig-chaos-orders --network "$NET" \
          --restart unless-stopped daig-orders:latest >/dev/null
        ;;
      2) # wrong credentials - starts, then fails readiness
        docker run -d --name daig-chaos-orders --network "$NET" \
          -e DATABASE_URL='postgresql://daig:WRONG_PASSWORD@postgres:5432/daig' \
          --restart unless-stopped daig-orders:latest >/dev/null
        ;;
      3) # port already bound - fails on listen
        docker run -d --name daig-chaos-orders --network "$NET" \
          -e DATABASE_URL="postgresql://daig:CHANGE_ME_DEV_ONLY@postgres:5432/daig" \
          -e PORT=1 --restart unless-stopped daig-orders:latest >/dev/null
        ;;
    esac
    echo "[chaos] container daig-chaos-orders is unhealthy."
    echo "[chaos] They must distinguish: config missing, config wrong, or"
    echo "[chaos] environment wrong. All three look identical from 'it is down'."
    echo "[chaos] Exit code is the fastest discriminator: docker inspect."
    ;;
  fix)
    docker rm -f daig-chaos-orders >/dev/null 2>&1 || true
    echo "[chaos] reverted"
    ;;
  *)
    sed -n '2,10p' "$0"
    ;;
esac
