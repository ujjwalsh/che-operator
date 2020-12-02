#!/bin/bash
#
# Copyright (c) 2012-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

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
CHANNEL="nightly"
export CHANNEL

# Test nightly olm files
NAMESPACE="che"
export NAMESPACE

export INSTALLATION_TYPE
INSTALLATION_TYPE="catalog"

export CSV_FILE="${OPERATOR_REPO}/deploy/olm-catalog/eclipse-che-preview-${platform}/manifests/che-operator.clusterserviceversion.yaml"

source "${OPERATOR_REPO}/olm/olm.sh" "${PLATFORM}" "${CSV_FILE}" "${NAMESPACE}" "${INSTALLATION_TYPE}"

# run function run the tests in ci of custom catalog source.
function run() {
    export OAUTH="false"

    oc project ${NAMESPACE}
    applyCRCheCluster
    sleep 180
    oc get pods -n $NAMESPACE
}

run

# grab che-operator namespace events after running olm nightly tests
oc get events -n ${NAMESPACE} | tee ${ARTIFACTS_DIR}/che-operator-events.log
