#!/bin/bash

set -euo pipefail

if [ $# -lt 3 ]; then
    echo "Usage: $0 <namespace> <redis_user> <redis_password> [expected-kube-context]"
    exit 1
fi

NAMESPACE=$1
REDIS_USER=$2
REDIS_PASSWORD=$3
REDIS_DATA_DIR=${REDIS_DATA_DIR:-$(pwd)/data}

# P23 (~/browseterm/p.md's "P23" section, plan section 22: "Every script checks kube context
# before applying"): this project runs two separate k3d clusters (Cloud/Local) reachable from the
# same host - applying against the wrong one is a real, previously-unguarded mistake class.
# Optional (empty = no check) so this doesn't break an existing call site not yet passing it.
EXPECTED_KUBE_CONTEXT=${4:-}
if [ -n "$EXPECTED_KUBE_CONTEXT" ]; then
    ACTUAL_KUBE_CONTEXT=$(kubectl config current-context)
    if [ "$ACTUAL_KUBE_CONTEXT" != "$EXPECTED_KUBE_CONTEXT" ]; then
        echo "ERROR: current kube context is '$ACTUAL_KUBE_CONTEXT', expected '$EXPECTED_KUBE_CONTEXT'. Aborting." >&2
        exit 1
    fi
fi

export NAMESPACE REDIS_USER REDIS_PASSWORD REDIS_DATA_DIR

REDIS_SINGLE_YAML=./redis_single/redis-single.yaml

echo "Setting up Redis single instance with ACL user..."

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Ensure data directory exists
mkdir -p "$REDIS_DATA_DIR/browseterm-redis"
chmod 755 "$REDIS_DATA_DIR/browseterm-redis"

# Apply Redis single YAML
envsubst < "$REDIS_SINGLE_YAML" | kubectl apply -n "$NAMESPACE" -f -

echo "Waiting for Redis pod to be ready..."
kubectl wait --for=condition=ready pod -l app=browseterm-redis -n "$NAMESPACE" --timeout=300s

echo "Creating Redis ACL user: $REDIS_USER"
# ACL SAVE persists the current ACL state to the --aclfile path (redis-single.yaml points it at
# /data/users.acl, on the same PVC as the RDB/AOF data), so redis-server reloads it automatically
# on every future restart instead of coming back up with only the passwordless default user -
# without this, any Redis pod restart (crash, node reboot, a `kubectl delete pod`) silently takes
# every login down until this ACL SETUSER block is manually re-run against the running pod.
kubectl exec -i browseterm-redis -n "$NAMESPACE" -- redis-cli --no-auth-warning << EOF
ACL SETUSER $REDIS_USER on +@all ~* >$REDIS_PASSWORD
ACL SETUSER default off
ACL SAVE
EOF

echo "Verifying user creation..."
kubectl exec browseterm-redis -n "$NAMESPACE" -- redis-cli --user "$REDIS_USER" -a "$REDIS_PASSWORD" --no-auth-warning ACL LIST

echo "Redis single instance setup complete!"
echo ""
echo "To connect to Redis:"
echo "kubectl exec -it browseterm-redis -n $NAMESPACE -- redis-cli --user $REDIS_USER -a $REDIS_PASSWORD"
echo ""
echo "Or port-forward to access from outside:"
echo "kubectl port-forward service/browseterm-redis-service -n $NAMESPACE 6379:6379"
echo "Then: redis-cli -h localhost -p 6379 --user $REDIS_USER -a $REDIS_PASSWORD"
