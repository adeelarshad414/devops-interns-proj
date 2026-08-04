#!/usr/bin/env bash
# DAY 2 CHAOS - Terraform state drift.
#
# The single most common real-world Terraform problem and almost never taught:
# somebody changed a resource in the console, so state and reality disagree.
#
#   ./chaos/day2-drift.sh aws|gcp|azure
#
# What they must do:
#   terraform plan            <- see the drift
#   terraform apply           <- overwrite the manual change, OR
#   terraform import          <- adopt something created by hand, OR
#   terraform state rm        <- forget something deleted by hand
#
# The judgement call is WHICH of those three is correct, and that is the lesson.
set -euo pipefail
CLOUD=${1:-help}

case "$CLOUD" in
  aws)
    cat <<'EOF'
[chaos] Instructor: apply ONE of these out-of-band, then have them run plan.

  1. Add an ingress rule to the app security group in the console
     aws ec2 authorize-security-group-ingress --group-id <sg> \
       --protocol tcp --port 22 --cidr 0.0.0.0/0
     (also a real security finding - tfsec will flag it)

  2. Change the RDS instance class in the console

  3. Delete a subnet tag that Terraform manages

Then: terraform plan. Ask them what SHOULD happen before they apply anything.
EOF
    ;;
  gcp)
    cat <<'EOF'
[chaos] Instructor: apply ONE out-of-band, then have them run plan.

  1. gcloud run services update daig-orders --set-env-vars=DRIFT=true
  2. Change the Cloud SQL tier in the console
  3. Remove an IAM binding Terraform manages

Then: terraform plan.
EOF
    ;;
  azure)
    cat <<'EOF'
[chaos] Instructor: apply ONE out-of-band, then have them run plan.

  1. az containerapp update -n daig-orders --set-env-vars DRIFT=true
  2. Scale the PostgreSQL Flexible Server SKU in the portal
  3. Add a tag to the resource group in the portal

Then: terraform plan.
EOF
    ;;
  *)
    sed -n '2,18p' "$0"
    ;;
esac
