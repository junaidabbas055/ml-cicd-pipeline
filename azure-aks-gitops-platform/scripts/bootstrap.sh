#!/usr/bin/env bash
# Bootstrap script: install ArgoCD + kube-prometheus-stack on a fresh AKS cluster.
# Usage: ./scripts/bootstrap.sh <kubeconfig-path> <environment>
set -euo pipefail

KUBECONFIG_PATH="${1:?Usage: bootstrap.sh <kubeconfig-path> <env>}"
ENVIRONMENT="${2:?Usage: bootstrap.sh <kubeconfig-path> <env>}"
export KUBECONFIG="$KUBECONFIG_PATH"

ARGOCD_VERSION="v2.10.4"
PROMETHEUS_CHART_VERSION="58.3.1"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

check_prereqs() {
  for cmd in kubectl helm curl; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found"; exit 1; }
  done
}

install_argocd() {
  log "Installing ArgoCD $ARGOCD_VERSION..."
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n argocd -f \
    "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

  log "Waiting for ArgoCD server to be ready..."
  kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

  log "Applying ArgoCD RBAC config..."
  kubectl apply -f argocd/install/argocd-install.yaml

  log "Bootstrapping app-of-apps..."
  kubectl apply -f argocd/apps/app-of-apps.yaml
}

install_monitoring() {
  log "Installing kube-prometheus-stack..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update

  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --version "$PROMETHEUS_CHART_VERSION" \
    --values "monitoring/prometheus/values.yaml" \
    --wait --timeout 10m

  log "Applying PrometheusRule alerts..."
  kubectl apply -f monitoring/prometheus/alerts/
}

apply_security_policies() {
  log "Applying network policies and CIS benchmark controls..."
  kubectl apply -f security/policies/
  kubectl apply -f security/rbac/
}

main() {
  log "=== AKS Platform Bootstrap — environment: $ENVIRONMENT ==="
  check_prereqs
  install_argocd
  install_monitoring
  apply_security_policies
  log "=== Bootstrap complete ==="
}

main "$@"
