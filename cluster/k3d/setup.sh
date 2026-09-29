#!/usr/bin/env bash
# Provision a k3d (k3s-in-Docker) cluster and swap its bundled Traefik for ingress-nginx.
#
# Extracted from BrowseTerm's own real, verified SETUP-CLOUD.md/SETUP-LOCAL.md steps 1-2
# (generalized - those docs' own remaining steps are project-specific app deploys, not part of
# this generic bootstrap). k3d clusters ship k3s's bundled Traefik by default; its `svclb`
# DaemonSet squats on host ports 80/443, so installing ingress-nginx BEFORE removing Traefik
# leaves ingress-nginx's own `svclb` Pending forever with nothing externally reachable
# (`kubectl -n kube-system get pods` showing a Pending `svclb-ingress-nginx-controller-*` pod is
# the tell) - this script always does the swap, not just on a suspected-broken retry.
#
# Idempotent: safe to re-run (`k3d cluster create` and the Traefik delete are both no-ops if
# already done; the ingress-nginx apply is a standard reconciling apply).
set -euo pipefail

# ── Config (override via env) ──
CLUSTER="${CLUSTER:-puhtaeto-k3d}"
LB_PORT="${LB_PORT:-8080}"              # host port -> the cluster's own port 80 (ingress-nginx)
INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-controller-v1.11.2}"

step() { echo; echo "▶ $*"; }

command -v k3d     >/dev/null || { echo "ERROR: k3d not installed (brew install k3d)"; exit 1; }
command -v kubectl >/dev/null || { echo "ERROR: kubectl not installed (brew install kubectl)"; exit 1; }
command -v docker  >/dev/null || { echo "ERROR: Docker not running (Docker Desktop or another engine)"; exit 1; }

CONTEXT="k3d-${CLUSTER}"

# ── 1. Create the cluster (skip if it already exists) ──
if k3d cluster list "$CLUSTER" >/dev/null 2>&1; then
  step "Cluster '${CLUSTER}' already exists - reusing"
else
  step "Creating k3d cluster '${CLUSTER}' (host port ${LB_PORT} -> cluster port 80)"
  k3d cluster create "$CLUSTER" -p "${LB_PORT}:80@loadbalancer" --wait --timeout 90s
fi
kubectl config use-context "$CONTEXT"

# ── 2. Remove the bundled Traefik, install ingress-nginx ──
step "Removing k3d's bundled Traefik (frees host ports 80/443 for ingress-nginx)"
kubectl --context "$CONTEXT" -n kube-system delete helmchart traefik --ignore-not-found

step "Installing ingress-nginx ${INGRESS_NGINX_VERSION}"
kubectl --context "$CONTEXT" apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml"
kubectl --context "$CONTEXT" -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s

cat <<EOF

✅ k3d cluster is up.
   Context : ${CONTEXT}  (kubectl config use-context ${CONTEXT})
   Ingress : host port ${LB_PORT} -> the cluster's ingress-nginx (verify with:
             kubectl --context ${CONTEXT} -n ingress-nginx get svc)

Next: deploy your own project's namespace/workloads/ingress rules onto this context.

Teardown: k3d cluster delete ${CLUSTER}   (deletes everything in this cluster - local dev only, no backups)
EOF
