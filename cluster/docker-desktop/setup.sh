#!/usr/bin/env bash
# Install ingress-nginx + MetalLB on Docker Desktop's own built-in Kubernetes.
#
# Docker Desktop's Kubernetes has no NetworkPolicy enforcement at all (its built-in CNI accepts
# per-tenant NetworkPolicies and silently ignores them) and no LoadBalancer provider, unlike a real
# cluster - MetalLB fills that second gap for local dev. If your project needs NetworkPolicy to
# actually be enforced (not just accepted), use ../k3s/ instead - that's the whole reason that
# setup exists. Extracted from this project's own real, verified ingress_nginx_setup.md.
#
# Idempotent: safe to re-run (helm upgrade --install, and both kubectl applies, all reconcile).
set -euo pipefail

step() { echo; echo "▶ $*"; }

command -v kubectl >/dev/null || { echo "ERROR: kubectl not installed (brew install kubectl)"; exit 1; }
command -v helm    >/dev/null || { echo "ERROR: helm not installed (brew install helm)"; exit 1; }

if ! kubectl config current-context 2>/dev/null | grep -q "docker-desktop"; then
  echo "⚠️  Current kubectl context is not 'docker-desktop' - continuing anyway, but double check"
  echo "   'kubectl config current-context' if that's not what you intended."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

step "Installing ingress-nginx via helm"
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s

step "Installing MetalLB"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s

step "Applying the MetalLB IP address pool (metallb-config.yaml, Docker Desktop's 192.168.65.x)"
kubectl apply -f "${SCRIPT_DIR}/metallb-config.yaml"

cat <<'EOF'

✅ ingress-nginx + MetalLB are up on Docker Desktop.
   Verify: kubectl -n ingress-nginx get svc   (should show a real EXTERNAL-IP like 192.168.65.2xx,
           not <pending>)

⚠️  Docker Desktop caveat: MetalLB's L2 IPs live inside the Docker Desktop VM network and are NOT
   reachable from your Mac host directly (a curl/ping to 192.168.65.2xx from macOS times out) - they
   ARE reachable in-cluster. To reach a service from your Mac browser/terminal, see local_ip_setup.md
   in this same directory (loopback IP aliases + kubectl port-forward), not the MetalLB IP directly.

Next: deploy your own project's namespace/workloads/Ingress objects onto this context.
EOF
