#!/bin/bash
#
# Copyright (c) 2012-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

export XDG_CONFIG_HOME=/tmp/chectl/config
export XDG_CACHE_HOME=/tmp/chectl/cache
export XDG_DATA_HOME=/tmp/chectl/data

set -ex

# Detect the base directory where che-operator is cloned
SCRIPT=$(readlink -f "$0")
export SCRIPT

OPERATOR_REPO=$(dirname "$(dirname "$SCRIPT")");
export OPERATOR_REPO

# ENV used by Openshift CI
ARTIFACTS_DIR="/tmp/artifacts"
export ARTIFACTS_DIR

# Execute olm nightly files in openshift
PLATFORM="openshift"
export PLATFORM

# Test nightly olm files
NAMESPACE="eclipse-che"
export NAMESPACE

#
export
OPERATOR_IMAGE=${CI_CHE_OPERATOR_IMAGE:-"quay.io/eclipse/che-operator:nightly"}

export CSV_FILE
CSV_FILE="${OPERATOR_REPO}/deploy/olm-catalog/eclipse-che-preview-${PLATFORM}/manifests/che-operator.clusterserviceversion.yaml"

source "${OPERATOR_REPO}"/.ci/util/ci_common.sh

function patchCheOperatorImage() {
    echo "[INFO] Getting che operator pod name..."
    operatorPod=$(oc get pods -o json -n ${NAMESPACE} | jq -r '.items[] | select(.metadata.name | test("che-operator-")).metadata.name')
    oc patch pod ${operatorPod} -n ${NAMESPACE} --type='json' -p='[{"op": "replace", "path": "/spec/containers/0/image", "value":'${OPERATOR_IMAGE}'}]'
    
    # The following command retrieve the operator image
    operatorImage=$(oc get pods -n ${NAMESPACE} -o json | jq -r '.items[] | select(.metadata.name | test("che-operator-")).spec.containers[].image')
    echo "[INFO] CHE operator image is ${operatorImage}"
}

function waitCheServerDeploy() {
  echo "[INFO] Waiting for Che server to be deployed"
  set +e -x

  i=0
  while [[ $i -le 480 ]]
  do
    status=$(oc get checluster/eclipse-che -n "${NAMESPACE}" -o jsonpath={.status.cheClusterRunning})
    oc get pods -n "${NAMESPACE}"
    if [ "${status:-UNAVAILABLE}" == "Available" ]
    then
      break
    fi
    sleep 10
    ((i++))
  done

  if [ $i -gt 480 ]
  then
    echo "[ERROR] Che server did't start after 8 minutes"
    exit 1
  fi
}

# run function run the tests in ci of custom catalog source.
function run() {
    export OAUTH="false"

    oc project ${NAMESPACE}
    applyCRCheCluster
    waitCheServerDeploy

    # Create and start a workspace
    getCheAcessToken
    chectl workspace:create --start --devfile=$OPERATOR_REPO/.ci/util/devfile-test.yaml

    getCheAcessToken
    chectl workspace:list
    waitWorkspaceStart

    oc get pods -n $NAMESPACE
}

patchCheOperatorImage
run

# grab che-operator namespace events after running olm nightly tests
oc get events -n ${NAMESPACE} | tee ${ARTIFACTS_DIR}/che-operator-events.log
