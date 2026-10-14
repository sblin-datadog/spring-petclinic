#!/usr/bin/env bash
# Send attack-pattern traffic to Petclinic so Datadog App & API Protection (AAP)
# raises security traces and signals. Targets ONLY your own demo deployment.
#
# Usage:
#   ./security-traffic.sh                 # auto: kubectl port-forward to the pod
#   BASE_URL=http://34.70.216.25:8181 ./security-traffic.sh   # hit a reachable URL directly
#
# Env:
#   BASE_URL   if set, send traffic here and skip port-forward
#   ROUNDS     how many times to repeat the full attack set (default 2)
#   NAMESPACE  k8s namespace for the port-forward fallback (default petclinic)
#   DEPLOY     k8s deployment for the port-forward fallback (default petclinic)
set -euo pipefail

ROUNDS="${ROUNDS:-2}"
NAMESPACE="${NAMESPACE:-petclinic}"
DEPLOY="${DEPLOY:-petclinic}"
PF_PID=""

die() { echo "Error: $*" >&2; exit 1; }
cleanup() { [ -n "$PF_PID" ] && kill "$PF_PID" 2>/dev/null || true; }
trap cleanup EXIT

# Pick a target: an explicit BASE_URL, otherwise a local port-forward to the pod.
if [ -n "${BASE_URL:-}" ]; then
  BASE="$BASE_URL"
else
  command -v kubectl >/dev/null || die "kubectl not found (or set BASE_URL to target the app directly)"
  echo "==> No BASE_URL set, opening port-forward to deploy/$DEPLOY in $NAMESPACE"
  kubectl port-forward -n "$NAMESPACE" "deploy/$DEPLOY" 8181:8080 >/tmp/petclinic-pf.log 2>&1 &
  PF_PID=$!
  BASE="http://127.0.0.1:8181"
  for _ in $(seq 1 15); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/" --max-time 3 2>/dev/null)" = "200" ] && break
    sleep 1
  done
fi

[ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/" --max-time 5 2>/dev/null)" = "200" ] \
  || die "app not reachable at $BASE (check port-forward log /tmp/petclinic-pf.log)"
echo "==> Target: $BASE  (rounds: $ROUNDS)"

enc() { python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
sent=0
hit() { curl -s -o /dev/null --max-time 5 "$@" 2>/dev/null || true; sent=$((sent+1)); }

# Known scanner User-Agents -> "Security Scanner Detected"
SCANNERS=(
  "sqlmap/1.7.2#stable (http://sqlmap.org)"
  "Nikto/2.1.6" "Mozilla/5.0 (Acunetix Web Vulnerability Scanner)"
  "Arachni/v1.5" "Nessus SOAP" "masscan/1.3"
  "Nmap Scripting Engine" "WPScan v3.8.0"
)
# SQL injection payloads -> attack_attempt.sql_injection
SQLI=(
  "' OR 1=1--" "1' UNION SELECT username,password FROM users--"
  "' OR 'a'='a" "1;WAITFOR DELAY '0:0:5'--"
  "' AND extractvalue(1,concat(0x7e,version()))--" "admin'--"
)
# Path traversal / LFI -> attack_attempt.lfi
TRAVERSAL=( "../../../../etc/passwd" "..%2f..%2f..%2fetc%2fpasswd" "....//....//etc/hosts" )
# XSS -> attack_attempt.xss
XSS=( "<script>alert(1)</script>" '"><img src=x onerror=alert(1)>' "javascript:alert(document.cookie)" )

for r in $(seq 1 "$ROUNDS"); do
  echo "--- round $r/$ROUNDS ---"
  for ua in "${SCANNERS[@]}"; do for _ in 1 2 3; do hit -A "$ua" "$BASE/owners?lastName=test"; done; done
  for p in "${SQLI[@]}";      do hit "$BASE/owners?lastName=$(enc "$p")"; done
  for p in "${TRAVERSAL[@]}"; do hit "$BASE/vets.html?f=$(enc "$p")"; done
  for p in "${XSS[@]}";       do hit "$BASE/owners?lastName=$(enc "$p")"; done
done

echo "==> Done, $sent requests sent."
echo "    Look in Datadog: Security > App and API Protection"
echo "    Traces filter:  @appsec.security_activity:* service:petclinic"
