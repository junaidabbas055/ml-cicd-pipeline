#!/usr/bin/env bash
# Bootstrap Jenkins on Kubernetes and configure it via JCasC.
# Usage: ./scripts/setup-jenkins.sh <kubeconfig>
set -euo pipefail

KUBECONFIG="${1:?Usage: setup-jenkins.sh <kubeconfig>}"
export KUBECONFIG

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Deploying Jenkins..."
kubectl apply -f kubernetes/jenkins/jenkins-deployment.yaml

log "Waiting for Jenkins to be ready..."
kubectl rollout status statefulset/jenkins -n jenkins --timeout=300s

JENKINS_POD=$(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
log "Jenkins pod: $JENKINS_POD"

log "Retrieving initial admin password..."
kubectl exec -n jenkins "$JENKINS_POD" -- cat /var/jenkins_home/secrets/initialAdminPassword

log "Jenkins is available at: http://jenkins.example.com"
log "Install suggested plugins, then configure pipeline from Jenkinsfile."
