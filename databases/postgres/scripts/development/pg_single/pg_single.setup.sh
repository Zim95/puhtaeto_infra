#!/bin/bash

if [ $# -lt 4 ]; then
    echo "Usage: $0 <namespace> <postgres_user> <postgres_password> <postgres_db> <postgres_test_db> [expected-kube-context]"
    exit 1
fi

NAMESPACE=$1
POSTGRES_USER=$2
POSTGRES_PASSWORD=$3
POSTGRES_PASSWORD_BASE64=$(echo -n $POSTGRES_PASSWORD | base64)
POSTGRES_DB=$4
POSTGRES_TEST_DB=$5
# P23 (~/browseterm/p.md's "P23" section, plan section 22: "Every script checks kube context
# before applying"): this project runs TWO separate k3d clusters (Cloud/Local) reachable from
# the same host - applying this manifest against the wrong one is a real, previously-unguarded
# mistake class. Optional (empty = no check, for anyone not yet passing it) so this doesn't
# suddenly break an existing call site that hasn't been updated with the new arg yet.
EXPECTED_KUBE_CONTEXT=${6:-}
if [ -n "$EXPECTED_KUBE_CONTEXT" ]; then
    ACTUAL_KUBE_CONTEXT=$(kubectl config current-context)
    if [ "$ACTUAL_KUBE_CONTEXT" != "$EXPECTED_KUBE_CONTEXT" ]; then
        echo "ERROR: current kube context is '$ACTUAL_KUBE_CONTEXT', expected '$EXPECTED_KUBE_CONTEXT'. Aborting." >&2
        exit 1
    fi
fi

export NAMESPACE=$NAMESPACE
export POSTGRES_USER=$POSTGRES_USER
export POSTGRES_PASSWORD=$POSTGRES_PASSWORD
export POSTGRES_DB=$POSTGRES_DB
export POSTGRES_TEST_DB=$POSTGRES_TEST_DB
export POSTGRES_PASSWORD_BASE64=$POSTGRES_PASSWORD_BASE64

POSTGRES_SINGLE_YAML=./pg_single/pg-single.yaml

envsubst < $POSTGRES_SINGLE_YAML | kubectl apply -n "$NAMESPACE" -f -
