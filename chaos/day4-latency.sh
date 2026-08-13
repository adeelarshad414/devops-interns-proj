#!/usr/bin/env bash
# DAY 4 CHAOS - Daig is slow at iftar. Nobody says which service.
#
# Turns on two independent defects:
#   dispatch  N+1 query        -> visible in TRACES
#   kitchen   O(n^2) hot loop  -> visible in PROFILES
#
# Metrics will only tell them "orders is slow". That is the point: each pillar
# answers a different question and none of them answers all of it.
#
#   ./chaos/day4-latency.sh break
#   ./chaos/day4-latency.sh fix
set -euo pipefail
ACTION=${1:-help}

case "$ACTION" in
  break)
    export CHAOS_SLOW_DISPATCH=true
    export CHAOS_HOT_SURGE_LOOP=true
    docker compose up -d --force-recreate --no-deps dispatch kitchen
    echo "[chaos] defects enabled. Now generate the spike:"
    echo "          PROFILE=spike node load/iftar-spike.js"
    echo
    echo "[chaos] expected path:"
    echo "          1 dashboard shows p95 > 1s SLO line"
    echo "          2 trace shows dispatch owns most of the time"
    echo "          3 inside dispatch: ~8 sequential count_rider_load spans"
    echo "          4 profile shows computeSurgeScore dominating kitchen CPU"
    echo "          5 fix: index + single grouped query, or the fast path"
    ;;
  fix)
    export CHAOS_SLOW_DISPATCH=false
    export CHAOS_HOT_SURGE_LOOP=false
    docker compose up -d --force-recreate --no-deps dispatch kitchen
    echo "[chaos] reverted. Re-run the load and compare p95 before/after."
    echo "[chaos] Have them screenshot both. The delta is their deliverable."
    ;;
  *)
    sed -n '2,14p' "$0"
    ;;
esac
