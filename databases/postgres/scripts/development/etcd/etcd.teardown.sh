#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <namespace>"
    exit 1
fi

YAML=./etcd/etcd.development.yaml
NAMESPACE=$1

export NAMESPACE=$NAMESPACE

envsubst < $YAML | kubectl delete -n "$NAMESPACE" -f -
