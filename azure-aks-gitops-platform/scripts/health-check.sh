#!/usr/bin/env bash
# Platform health check: validates ArgoCD app sync status, node readiness,
# and Prometheus alert firing state.
# Usage: ./scripts/health-check.sh [namespace]
set -euo pipefail

NAMESPACE="${1:-myapp-dev}"
PASS=0
FAIL=0

green() { echo -e "\033[32m✔ $*\033[0m"; }
red()   { echo -e "\033[31m✘ $*\033[0m"; }

check() {
  local description="$1"; shift
  if "$@" &>/dev/null; then
    green "$description"
    ((PASS++)) || true
  else
    red "$description"
    ((FAIL++)) || true
  fi
}

echo "=== Platform Health Check ==="
echo ""

echo "--- Nodes ---"
NOTREADY=$(kubectl get nodes --no-headers | grep -v " Ready" | wc -l)
if [ "$NOTREADY" -eq 0 ]; then
  green "All nodes Ready"
  ((PASS++)) || true
else
  red "$NOTREADY node(s) not Ready"
  ((FAIL++)) || true
fi

echo ""
echo "--- ArgoCD Applications ---"
while IFS= read -r app; do
  SYNC=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
  HEALTH=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
  if [ "$SYNC" = "Synced" ] && [ "$HEALTH" = "Healthy" ]; then
    green "ArgoCD app $app — Synced/Healthy"
    ((PASS++)) || true
  else
    red "ArgoCD app $app — Sync:$SYNC Health:$HEALTH"
    ((FAIL++)) || true
  fi
done < <(kubectl get applications -n argocd --no-headers -o custom-columns=":metadata.name" 2>/dev/null)

echo ""
echo "--- Namespace: $NAMESPACE ---"
check "Prometheus scraping targets up" \
  kubectl get servicemonitor -n monitoring --no-headers

FIRING=$(kubectl exec -n monitoring deploy/monitoring-kube-prometheus-prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/alerts?state=firing' 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['data']['alerts']))" 2>/dev/null || echo "0")

if [ "$FIRING" -eq 0 ]; then
  green "No firing Prometheus alerts"
  ((PASS++)) || true
else
  red "$FIRING firing Prometheus alert(s)"
  ((FAIL++)) || true
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
