#!/usr/bin/env bash
# Deploy a single-instance Redis (with a persistent AOF volume) into the shared `data` namespace.
#
# Adapted from ikompare's own real, production-verified deploy/data/ manifests (see
# redis-deployment.yaml's own comments for a real bug already hit and fixed there: runAsNonRoot
# alone, with no explicit runAsUser, makes kubelet refuse to start the official redis image at all).
# The `data` namespace and its NetworkPolicy are shared with ../postgres/ (see ../namespace.yaml's
# own comment) - safe to apply from either setup.sh, idempotent either way.
#
# Idempotent: safe to re-run.
set -euo pipefail

step() { echo; echo "▶ $*"; }

command -v kubectl >/dev/null || { echo "ERROR: kubectl not installed"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

step "Applying the shared 'data' namespace + NetworkPolicy"
kubectl apply -f "${SCRIPT_DIR}/../namespace.yaml"
kubectl apply -n data -f "${SCRIPT_DIR}/../networkpolicy.yaml"

step "Applying Redis PVC + Service + Deployment"
kubectl apply -n data -f "${SCRIPT_DIR}/redis-pvc.yaml"
kubectl apply -n data -f "${SCRIPT_DIR}/redis-service.yaml"
kubectl apply -n data -f "${SCRIPT_DIR}/redis-deployment.yaml"

step "Waiting for the redis Deployment to be ready"
kubectl -n data rollout status deployment/redis --timeout=120s

cat <<'EOF'

✅ Redis is up in the 'data' namespace.
   Connect from another namespace by labeling it `data-access: "true"` (see ../networkpolicy.yaml),
   then reach it at redis.data.svc.cluster.local:6379.
EOF
