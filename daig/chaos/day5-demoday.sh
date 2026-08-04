#!/usr/bin/env bash
# DAY 5 - DEMO DAY. Nine scenarios. Pick one per intern, at random, in front
# of the room. Ten minutes each.
#
#   ./chaos/day5-demoday.sh list
#   ./chaos/day5-demoday.sh run <n> <namespace>
#   ./chaos/day5-demoday.sh fix <n> <namespace>
#
# Scoring, per the kickoff deck:
#   40% diagnosis method  30% the fix  20% explanation  10% composure
# A well-reasoned failed diagnosis scores above a lucky guess. Say so first.
set -euo pipefail
ACTION=${1:-list}
N=${2:-1}
NS=${3:-default}
K="kubectl -n $NS"

list() {
  cat <<'EOF'
  1  Image tag does not exist              -> ImagePullBackOff
  2  Secret key renamed                    -> CreateContainerConfigError
  3  Memory limit set to 16Mi              -> OOMKilled, then CrashLoopBackOff
  4  Readiness probe points at wrong port   -> pods Running but never Ready
  5  Service selector typo                 -> endpoints empty, 503 at ingress
  6  Replicas scaled to 0                  -> no pods, no error anywhere
  7  ConfigMap DATABASE_URL wrong host      -> exits 78 on boot
  8  CPU limit 50m                          -> throttled, latency SLO breach
  9  NetworkPolicy blocks egress to the DB  -> readiness 503, no logs to explain it
EOF
}

case "$ACTION" in
  list) list ;;
  run)
    case "$N" in
      1) $K set image deploy/orders orders=ghcr.io/tkxel/daig-orders:v9-does-not-exist ;;
      2) $K patch deploy/orders --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"WRONG_KEY"}]' ;;
      3) $K set resources deploy/orders --limits=memory=16Mi ;;
      4) $K patch deploy/orders --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/port","value":9999}]' ;;
      5) $K patch svc/orders --type=json -p='[{"op":"replace","path":"/spec/selector/app","value":"orders-typo"}]' ;;
      6) $K scale deploy/orders --replicas=0 ;;
      7) $K patch configmap/daig-config --type=json -p='[{"op":"replace","path":"/data/POSTGRES_HOST","value":"postgres-wrong"}]' && $K rollout restart deploy/orders ;;
      8) $K set resources deploy/orders --limits=cpu=50m ;;
      9) $K apply -f k8s/chaos/deny-egress.yaml ;;
      *) echo "unknown scenario $N"; list; exit 1 ;;
    esac
    echo "[demoday] scenario $N applied in namespace $NS. Hand them the keyboard."
    ;;
  fix)
    case "$N" in
      9) $K delete -f k8s/chaos/deny-egress.yaml --ignore-not-found ;;
      *) $K rollout undo deploy/orders || $K apply -f k8s/base/ ;;
    esac
    echo "[demoday] scenario $N reverted"
    ;;
  *) list ;;
esac
