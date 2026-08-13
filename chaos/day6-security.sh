#!/usr/bin/env bash
# DEVSECOPS CHAOS - find and fix six real vulnerabilities.
#
#   ./chaos/day6-security.sh break     # enable the vulnerable endpoints
#   ./chaos/day6-security.sh hints     # progressive hints, one at a time
#   ./chaos/day6-security.sh verify    # check which are still exploitable
#   ./chaos/day6-security.sh fix       # turn them off again
#
# The exercise is NOT "run a scanner and read the output". It is:
#   1. run the scanners
#   2. triage what they found - which of these actually matters here?
#   3. find the one they MISSED
#   4. fix three of them properly
#   5. add a gate so the fix cannot regress
#
# Step 3 is the point. Step 5 is what separates DevSecOps from security.
set -euo pipefail
ACTION=${1:-help}
ORDERS=${ORDERS:-http://localhost:3001}

case "$ACTION" in
  break)
    echo "[sec] enabling INSECURE_MODE on orders..."
    CHAOS_ENV=INSECURE_MODE=true docker compose up -d --force-recreate --no-deps orders
    cat <<'EOF'

[sec] Six vulnerabilities are now live on /insecure/*. Your job:

  1. RUN THE TOOLS
       ./security/scan-all.sh sast
       ./security/scan-all.sh secrets
       docker compose -f docker-compose.yml -f docker-compose.security.yml \
         --profile dast run --rm zap

  2. TRIAGE
       Semgrep will report several findings. For each one, decide:
         - is it real?
         - is it reachable?
         - what is the actual impact HERE, in this system?
       A finding is not a vulnerability until you can say what it lets someone do.

  3. FIND THE ONE THE TOOLS MISSED
       One of the six is essentially invisible to every scanner you just ran.
       Which, and why? The answer tells you what tools are for and what they
       are not for.

  4. FIX THREE, PROPERLY
       Each vulnerable handler in services/orders/src/insecure.js has the
       correct implementation in a comment beneath it. Do not just uncomment -
       understand why the fix is the fix.

  5. ADD A GATE
       Write a Semgrep rule, an OPA policy, or a test that makes your fix
       permanent. A fix without a gate regresses within two sprints.
       This step is the difference between doing security and doing DevSecOps.

EOF
    ;;

  hints)
    cat <<'EOF'
[hint 1] Start with the scanner that needs no running code. SAST is cheapest.

[hint 2] Semgrep will flag string-concatenated SQL, MD5, a stack trace in a
         response, process.env in a response, and an unvalidated fetch(). That
         is five. There are six.

[hint 3] The sixth has parameterised SQL, no injection, no unsafe call, and
         nothing a tool can point at. The code is not wrong. Something is
         MISSING from it.

[hint 4] Compare GET /api/orders/:id with GET /insecure/orders/:id. They look
         almost identical. Ask: who is allowed to read this order?

[hint 5] It is broken object-level authorisation - IDOR. No scanner finds it
         because "who should be allowed to see this" is a business rule, and a
         tool cannot know your business rules. It is #1 on the OWASP API Top 10
         for exactly this reason.

[hint 6] Which means: tools find CLASSES of bug. Humans find MISSING RULES.
         Code review is not a formality you do after the scanners pass.
EOF
    ;;

  verify)
    echo "[sec] probing each vulnerability. 'STILL VULNERABLE' means unfixed."
    echo

    probe() {
      local name=$1 expect_vuln=$2 result=$3
      if [ "$result" = "vuln" ]; then
        printf '  %-38s \033[31mSTILL VULNERABLE\033[0m\n' "$name"
      else
        printf '  %-38s \033[32mfixed or unreachable\033[0m\n' "$name"
      fi
    }

    # VULN-1: does a quote break the query, or get treated as data?
    r=$(curl -s "$ORDERS/insecure/search?q=%27" 2>/dev/null || echo '')
    case "$r" in
      *executed_sql*|*syntax*) probe "VULN-1 SQL injection" y vuln ;;
      *) probe "VULN-1 SQL injection" y ok ;;
    esac

    # VULN-3: is a stack trace coming back?
    r=$(curl -s "$ORDERS/insecure/boom" 2>/dev/null || echo '')
    case "$r" in
      *stack*|*postgresql://*) probe "VULN-3 error disclosure" y vuln ;;
      *) probe "VULN-3 error disclosure" y ok ;;
    esac

    # VULN-4: md5?
    r=$(curl -s -X POST "$ORDERS/insecure/register" \
        -H 'content-type: application/json' \
        -d '{"username":"t","password":"t"}' 2>/dev/null || echo '')
    case "$r" in
      *md5*) probe "VULN-4 weak hashing" y vuln ;;
      *) probe "VULN-4 weak hashing" y ok ;;
    esac

    # VULN-6: SSRF - point it at something harmless and local
    r=$(curl -s -X POST "$ORDERS/insecure/fetch-menu" \
        -H 'content-type: application/json' \
        -d '{"url":"http://127.0.0.1:3001/healthz"}' 2>/dev/null || echo '')
    case "$r" in
      *'"status":200'*) probe "VULN-6 SSRF" y vuln ;;
      *) probe "VULN-6 SSRF" y ok ;;
    esac

    echo
    echo "  VULN-2 (IDOR) and VULN-5 (no rate limit) cannot be probed this way."
    echo "  That is itself the lesson: an automated check needs to know what"
    echo "  SHOULD happen, and for authorisation only you know that."
    ;;

  fix)
    docker compose up -d --force-recreate --no-deps orders
    echo "[sec] INSECURE_MODE off. Endpoints gone."
    ;;

  *)
    sed -n '2,18p' "$0"
    ;;
esac
