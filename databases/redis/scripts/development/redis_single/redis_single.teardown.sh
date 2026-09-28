#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <namespace>"
    exit 1
fi

NAMESPACE=$1
export NAMESPACE=$NAMESPACE

REDIS_SINGLE_YAML=./redis_single/redis-single.yaml

envsubst < $REDIS_SINGLE_YAML | kubectl delete -n "$NAMESPACE" -f -
