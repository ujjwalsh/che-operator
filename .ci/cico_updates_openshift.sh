#!/bin/bash
#
# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

set -ex
export OO_INSTALL_NAMESPACE="eclipse-che"

echo -e "Catalog image it is: $CI_CATALOG_SOURCE_IMAGE"

oc create namespace $OO_INSTALL_NAMESPACE

OPERATORGROUP=$(
    oc create -f - -o jsonpath='{.metadata.name}' <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: operatorgroup
  namespace: $OO_INSTALL_NAMESPACE
spec:
  targetNamespaces:
  - $OO_INSTALL_NAMESPACE
EOF
)

CATSRC=$(
    oc create -f - -o jsonpath='{.metadata.name}' <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  generateName: oo-
  namespace: $OO_INSTALL_NAMESPACE
spec:
  sourceType: grpc
  image: quay.io/flavius_lacatusu/che-bundles:latest
EOF
)

echo "CatalogSource name is \"$CATSRC\""
echo "Creating Subscription"


export platform="openshift"
export OPERATOR_REPO=$(dirname $(dirname $(readlink -f "$0")));
export channel="stable"
export INSTALLATION_TYPE="catalog"

packageName=eclipse-che-preview-${platform}
platformPath=${OPERATOR_REPO}/olm/${packageName}
packageFolderPath="${platformPath}/deploy/olm-catalog/${packageName}"
packageFilePath="${packageFolderPath}/${packageName}.package.yaml"

LATEST_CSV_NAME=$(yq -r ".channels[] | select(.name == \"${channel}\") | .currentCSV" "${packageFilePath}")
lastPackageVersion=$(echo "${LATEST_CSV_NAME}" | sed -e "s/${packageName}.v//")
PREVIOUS_CSV_NAME=$(sed -n 's|^ *replaces: *\([^ ]*\) *|\1|p' "${packageFolderPath}/${lastPackageVersion}/${packageName}.v${lastPackageVersion}.clusterserviceversion.yaml")
PACKAGE_VERSION=$(echo "${PREVIOUS_CSV_NAME}" | sed -e "s/${packageName}.v//")
INSTALLATION_TYPE="Marketplace"

source "${OPERATOR_REPO}/olm/olm.sh" "${platform}" "${PACKAGE_VERSION}" "$OO_INSTALL_NAMESPACE" "${INSTALLATION_TYPE}"
source "${OPERATOR_REPO}"/.github/bin/common.sh

SUB=$(
    oc create -f - -o jsonpath='{.metadata.name}' <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: $packageName
  namespace: $OO_INSTALL_NAMESPACE
spec:
  name: eclipse-che-preview-openshift
  channel: stable
  installPlanApproval: Manual
  source: $CATSRC
  sourceNamespace: $OO_INSTALL_NAMESPACE
  startingCSV: ${PREVIOUS_CSV_NAME}
EOF
)
kubectl describe subscription/"$SUB" -n "${OO_INSTALL_NAMESPACE}"

kubectl wait subscription/"$SUB" -n "${OO_INSTALL_NAMESPACE}" --for=condition=InstallPlanPending --timeout=240s

if [ $? -ne 0 ]
then
  echo Subscription failed to install the operator
  exit 1
fi

kubectl describe subscription/"$SUB" -n "${OO_INSTALL_NAMESPACE}"

installPackage
echo -e "\u001b[32m Installation of the previous che-operator version: ${PREVIOUS_CSV_NAME} successfully completed \u001b[0m"
applyCRCheCluster
waitCheServerDeploy

installPackage
echo -e "\u001b[32m Installation of the latest che-operator version: ${LATEST_CSV_NAME} successfully completed \u001b[0m"

sleep 2m

oc get pods -n $OO_INSTALL_NAMESPACE
