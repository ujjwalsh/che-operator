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
  name: che-ogroup
  namespace: $OO_INSTALL_NAMESPACE
spec:
  targetNamespaces: [$OO_TARGET_NAMESPACES]
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
  image: "$CI_CATALOG_SOURCE_IMAGE"
EOF
)

echo "CatalogSource name is \"$CATSRC\""
echo "Creating Subscription"

SUB=$(
    oc create -f - -o jsonpath='{.metadata.name}' <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  generateName: oo-
  namespace: $OO_INSTALL_NAMESPACE
spec:
  name: eclipse-che-preview-openshift
  channel: "stable"
  source: $CATSRC
  sourceNamespace: $OO_INSTALL_NAMESPACE
EOF
)

echo "Subscription naeeeme is \"$SUB\""
echo "Waiting for ClusterServiceVersion to become ready..."

for _ in $(seq 1 30); do
    CSV=$(oc -n "$OO_INSTALL_NAMESPACE" get subscription "$SUB" -o jsonpath='{.status.installedCSV}' || true)
    if [[ -n "$CSV" ]]; then
        if [[ "$(oc -n "$OO_INSTALL_NAMESPACE" get csv "$CSV" -o jsonpath='{.status.phase}')" == "Succeeded" ]]; then
            echo "ClusterServiceVersion \"$CSV\" ready"
            exit 0
        fi
    fi
    sleep 10
done

sleep 2m

oc get pods -n $OO_INSTALL_NAMESPACE
