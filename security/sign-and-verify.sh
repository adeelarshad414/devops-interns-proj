#!/usr/bin/env bash
# Supply-chain integrity with cosign: sign an image, attach its SBOM, verify.
#
# The question this answers: "how do you know the image running in production
# is the one your pipeline built?" Without signing, you do not. You are
# trusting the registry, the network, and everyone with push access.
#
# Keyless signing means there is no private key to steal, rotate or leak. The
# signing identity IS the CI workflow, so a valid signature proves which
# pipeline produced the artifact. That property is what makes it worth teaching.
set -euo pipefail

IMAGE=${1:?usage: sign-and-verify.sh <image-ref>}
REPO_ID=${GITHUB_REPOSITORY:-adeelarshad414/daig}

hr() { printf '\n\033[1m=== %s ===\033[0m\n' "$1"; }

hr "1. Sign (keyless, via OIDC)"
# In CI this is non-interactive: the GitHub Actions OIDC token is the identity.
# Locally it opens a browser for an OAuth flow, which is itself a good
# demonstration of what "the identity is a human or a workflow" means.
cosign sign --yes "$IMAGE"

hr "2. Generate and attach an SBOM as an attestation"
syft "$IMAGE" -o cyclonedx-json > sbom.cdx.json
cosign attest --yes --predicate sbom.cdx.json --type cyclonedx "$IMAGE"

hr "3. Verify the signature"
# This is the step a Kyverno policy performs at admission time. Run it by hand
# once so the policy is not magic.
cosign verify "$IMAGE" \
  --certificate-identity-regexp "https://github.com/${REPO_ID}/.github/workflows/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"

hr "4. Verify the SBOM attestation"
cosign verify-attestation "$IMAGE" --type cyclonedx \
  --certificate-identity-regexp "https://github.com/${REPO_ID}/.github/workflows/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"

hr "5. Now try to verify something we did not sign"
echo "This SHOULD fail. Watch it fail - a check that never fails proves nothing."
cosign verify docker.io/library/nginx:latest \
  --certificate-identity-regexp ".*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  || echo "  correctly rejected: no matching signature"
