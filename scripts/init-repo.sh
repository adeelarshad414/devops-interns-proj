#!/usr/bin/env bash
# Turn this directory into a Git repository ready to push.
#
#   ./scripts/init-repo.sh git@github.com:adeelarshad414/daig.git
#
# Checks for leaked credentials BEFORE the first commit, because the first
# commit is the one people are least careful about and Git history is forever.
set -euo pipefail

REMOTE=${1:-}

hr() { printf '\n\033[1m--- %s\033[0m\n' "$1"; }

hr "1. pre-flight: is there anything here that must not be committed?"
BAD=0

for f in .env vault/.init-keys.json; do
  if [ -e "$f" ]; then
    echo "  present: $f  (gitignored - confirming)"
    grep -qxF "$(basename "$f")" .gitignore 2>/dev/null \
      || grep -qF "$f" .gitignore \
      || { echo "    NOT IGNORED. Stopping."; BAD=1; }
  fi
done

if [ -d vault/.approle ]; then
  echo "  present: vault/.approle/  (gitignored - confirming)"
  grep -qF 'vault/.approle/' .gitignore || { echo "    NOT IGNORED. Stopping."; BAD=1; }
fi

if grep -rn --exclude-dir=.git --exclude-dir=node_modules \
     -E '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' . 2>/dev/null; then
  echo "  possible real credential found above. Stopping."
  BAD=1
fi

[ "$BAD" -eq 0 ] || { echo; echo "Fix the above before initialising."; exit 1; }
echo "  clean"

hr "2. git init"
if [ -d .git ]; then
  echo "  already a git repository"
else
  git init -b main
fi

hr "3. install the pre-commit hook"
cp .githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
echo "  installed"

hr "4. static checks before the first commit"
make check

hr "5. first commit"
git add -A
git status --short | head -30
echo "  ... $(git status --short | wc -l | tr -d ' ') files staged"
echo
git commit -q -m "feat: initial Daig teaching platform

Three-tier demo application for the tkxel DevOps intern rotation.

- three tiers: nginx, three Node services, Postgres and Redis
- OpenBao credential store with AppRole and least-privilege policies
- full observability: OTel, Prometheus, Loki, Tempo, Pyroscope, Grafana
- seven-gate DevSecOps pipeline with six deliberate vulnerabilities
- Terraform for AWS, GCP and Azure; Ansible; Kubernetes; Swarm
- six chaos exercises and twelve documentation files

Nothing in this commit has been executed. See VERIFICATION.md." \
  || echo "  nothing to commit"

echo "  committed"

if [ -n "$REMOTE" ]; then
  hr "6. remote"
  git remote remove origin 2>/dev/null || true
  git remote add origin "$REMOTE"
  echo "  origin -> $REMOTE"
  echo
  echo "Push with:"
  echo "    git push -u origin main"
  echo
  echo "Then, on the forge:"
  echo "  - protect main: require PR, require CI, require a CODEOWNERS review"
  echo "  - enable secret scanning and push protection"
  echo "  - add repository secrets: SONAR_TOKEN, SONAR_HOST_URL"
  echo "  - update the handles in .github/CODEOWNERS"
else
  hr "6. remote"
  echo "  no remote given. Add one with:"
  echo "    git remote add origin git@github.com:<you>/daig.git"
  echo "    git push -u origin main"
fi
