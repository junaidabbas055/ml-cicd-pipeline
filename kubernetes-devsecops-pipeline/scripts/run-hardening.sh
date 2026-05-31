#!/usr/bin/env bash
# Run CIS L2 hardening playbook against target environment.
# Usage: ./scripts/run-hardening.sh <env> [--check]
set -euo pipefail

ENV="${1:?Usage: run-hardening.sh <dev|staging|prod> [--check]}"
CHECK_FLAG="${2:-}"

cd ansible

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Running CIS L2 hardening on $ENV environment $CHECK_FLAG..."
ansible-playbook \
  -i "inventory/${ENV}.ini" \
  $CHECK_FLAG \
  playbook-hardening.yml \
  -e "env=$ENV"

log "Hardening complete."
