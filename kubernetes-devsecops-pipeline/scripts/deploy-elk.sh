#!/usr/bin/env bash
# Deploy ELK stack to Kubernetes logging namespace.
# Usage: ./scripts/deploy-elk.sh <kubeconfig> <elastic-password>
set -euo pipefail

KUBECONFIG="${1:?Usage: deploy-elk.sh <kubeconfig> <elastic-password>}"
ELASTIC_PASSWORD="${2:?Usage: deploy-elk.sh <kubeconfig> <elastic-password>}"
export KUBECONFIG

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Creating logging namespace and secrets..."
kubectl apply -f kubernetes/elk/elasticsearch.yaml

kubectl create secret generic elasticsearch-secret \
  --from-literal=password="$ELASTIC_PASSWORD" \
  -n logging \
  --dry-run=client -o yaml | kubectl apply -f -

log "Deploying Elasticsearch..."
kubectl apply -f kubernetes/elk/elasticsearch.yaml
kubectl rollout status statefulset/elasticsearch -n logging --timeout=300s

log "Deploying Logstash..."
kubectl apply -f kubernetes/elk/logstash.yaml
kubectl rollout status deployment/logstash -n logging --timeout=180s

log "Deploying Kibana..."
kubectl apply -f kubernetes/elk/kibana.yaml
kubectl rollout status deployment/kibana -n logging --timeout=180s

log "=== ELK Stack deployed ==="
log "Kibana:        http://kibana.example.com"
log "Elasticsearch: http://elasticsearch.logging.svc:9200"
