#!/usr/bin/env bash
# Deploy a single-instance PostgreSQL into the shared `data` namespace.
#
# Adapted from ikompare's own real, production-verified deploy/data/ manifests (see
# postgres-statefulset.yaml's own comments for two real bugs already hit and fixed there: the
# official image's first-run chown needing root capabilities kept, not dropped, and Kubernetes not
# expanding $(VAR) inside a probe's exec.command). The `data` namespace and its NetworkPolicy are
# shared with ../redis/ (see ../namespace.yaml's own comment) - safe to apply from either
# setup.sh, idempotent either way.
#
# Idempotent: safe to re-run.
set -euo pipefail

step() { echo; echo "▶ $*"; }

command -v kubectl >/dev/null || { echo "ERROR: kubectl not installed"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/postgres.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: ${ENV_FILE} not found. Copy postgres.env.example to postgres.env and fill in real values first."
  exit 1
fi

step "Applying the shared 'data' namespace + NetworkPolicy"
kubectl apply -f "${SCRIPT_DIR}/../namespace.yaml"
kubectl apply -n data -f "${SCRIPT_DIR}/../networkpolicy.yaml"

step "Creating/updating the postgres-credentials Secret from postgres.env"
kubectl -n data create secret generic postgres-credentials --from-env-file="$ENV_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

step "Applying PostgreSQL Service + StatefulSet"
kubectl apply -n data -f "${SCRIPT_DIR}/postgres-service.yaml"
kubectl apply -n data -f "${SCRIPT_DIR}/postgres-statefulset.yaml"

step "Waiting for the postgres StatefulSet to be ready"
kubectl -n data rollout status statefulset/postgres --timeout=180s

cat <<'EOF'

✅ PostgreSQL is up in the 'data' namespace.
   Connect from another namespace by labeling it `data-access: "true"` (see ../networkpolicy.yaml),
   then reach it at postgres.data.svc.cluster.local:5432.
EOF
