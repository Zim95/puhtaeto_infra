#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <namespace>"
    exit 1
fi

NAMESPACE=$1
export NAMESPACE=$NAMESPACE

POSTGRES_SINGLE_YAML=./pg_single/pg-single.yaml

envsubst < $POSTGRES_SINGLE_YAML | kubectl delete -n "$NAMESPACE" -f -
