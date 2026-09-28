#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <namespace>"
    exit 1
fi

NAMESPACE=$1
export NAMESPACE=$NAMESPACE

PATRONI_CONFIG_YAML=./postgres/development/patroni.configmap.yaml
PATRONI_STATEFULSET_YAML=./postgres/development/postgres.statefulset.yaml
PATRONI_POD_DISCOVERY_YAML=./postgres/development/headless.poddiscovery.yaml

# this has to be done in order
envsubst < $PATRONI_CONFIG_YAML | kubectl delete -n "$NAMESPACE" -f -
envsubst < $PATRONI_STATEFULSET_YAML | kubectl delete -n "$NAMESPACE" -f -
envsubst < $PATRONI_POD_DISCOVERY_YAML | kubectl delete -n "$NAMESPACE" -f -
