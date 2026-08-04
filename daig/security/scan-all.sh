#!/usr/bin/env bash
# Runs the whole DevSecOps toolchain locally, in the same order CI runs it.
#
#   ./security/scan-all.sh              # everything that needs no cluster
#   ./security/scan-all.sh secrets      # just one stage
#
# Every tool runs in a container so nothing needs installing. That is itself
# worth pointing out: your security toolchain is a set of images, which means it
# is versioned, reproducible, and identical locally and in CI.
set -uo pipefail

STAGE=${1:-all}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/security/reports"
mkdir -p "$OUT"
fail=0

hr() { printf '\n\033[1m=== %s ===\033[0m\n' "$1"; }

# 1 ---------------------------------------------------------------- SECRETS
if [ "$STAGE" = all ] || [ "$STAGE" = secrets ]; then
  hr "SECRETS - gitleaks (scans history, not just the working tree)"
  docker run --rm -v "$ROOT:/repo" zricethezav/gitleaks:latest \
    detect --source=/repo --report-path=/repo/security/reports/gitleaks.json \
    --redact --verbose || { echo "gitleaks found something"; fail=1; }
fi

# 2 ------------------------------------------------------------------- SAST
if [ "$STAGE" = all ] || [ "$STAGE" = sast ]; then
  hr "SAST - semgrep (registry rules + our own)"
  docker run --rm -v "$ROOT:/src" returntocorp/semgrep:latest \
    semgrep scan \
      --config=p/javascript \
      --config=p/nodejs \
      --config=p/owasp-top-ten \
      --config=/src/security/semgrep/daig.yml \
      --json --output=/src/security/reports/semgrep.json \
      --error || { echo "semgrep found issues"; fail=1; }
fi

# 3 -------------------------------------------------------------------- SCA
if [ "$STAGE" = all ] || [ "$STAGE" = deps ]; then
  hr "SCA - dependency vulnerabilities"
  for svc in orders kitchen dispatch; do
    echo "-- $svc"
    docker run --rm -v "$ROOT/services/$svc:/app" -w /app node:22-alpine \
      sh -c "npm install --silent --no-audit --no-fund >/dev/null 2>&1; npm audit --audit-level=high" \
      || { echo "  high or critical advisories in $svc"; fail=1; }
  done
fi

# 4 ------------------------------------------------------------------ IMAGE
if [ "$STAGE" = all ] || [ "$STAGE" = image ]; then
  hr "IMAGE - trivy"
  for svc in orders kitchen dispatch web; do
    echo "-- daig-$svc"
    docker build -q -f "$ROOT/services/$svc/Dockerfile" -t "daig-$svc:scan" "$ROOT" >/dev/null
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$OUT:/out" aquasec/trivy:latest image \
      --severity HIGH,CRITICAL --exit-code 1 \
      --format json --output "/out/trivy-$svc.json" \
      "daig-$svc:scan" || { echo "  vulnerabilities in daig-$svc"; fail=1; }
  done
fi

# 5 -------------------------------------------------------------------- IaC
if [ "$STAGE" = all ] || [ "$STAGE" = iac ]; then
  hr "IaC - trivy config + conftest policies"
  docker run --rm -v "$ROOT:/repo" aquasec/trivy:latest config \
    --severity HIGH,CRITICAL /repo/infra || { echo "IaC misconfigurations"; fail=1; }

  echo "-- conftest: dockerfiles"
  for svc in orders kitchen dispatch web; do
    docker run --rm -v "$ROOT:/project" openpolicyagent/conftest:latest \
      test --policy security/policy --parser dockerfile \
      "services/$svc/Dockerfile" || fail=1
  done

  echo "-- conftest: kubernetes"
  docker run --rm -v "$ROOT:/project" openpolicyagent/conftest:latest \
    test --policy security/policy k8s/base/ || fail=1
fi

# 6 ------------------------------------------------------------------- SBOM
if [ "$STAGE" = all ] || [ "$STAGE" = sbom ]; then
  hr "SBOM - syft"
  for svc in orders kitchen dispatch; do
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$OUT:/out" anchore/syft:latest \
      "daig-$svc:scan" -o cyclonedx-json="/out/sbom-$svc.cdx.json" 2>/dev/null \
      && echo "  sbom-$svc.cdx.json written" \
      || echo "  skipped $svc (image not built - run the image stage first)"
  done
  echo
  echo "An SBOM is only useful if you keep it. When the next Log4Shell lands,"
  echo "the question is 'which of our 200 services ship that library' and the"
  echo "SBOM is the only thing that answers it in minutes rather than weeks."
fi

hr "SUMMARY"
if [ "$fail" -eq 0 ]; then
  echo "all stages passed. Reports in security/reports/"
else
  echo "one or more stages found issues. Reports in security/reports/"
  echo "This is the expected result on a first run - Daig has deliberate"
  echo "vulnerabilities. Triage them, do not just make the output green."
fi
exit "$fail"
