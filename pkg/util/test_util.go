//
// Copyright (c) 2012-2019 Red Hat, Inc.
// This program and the accompanying materials are made
// available under the terms of the Eclipse Public License 2.0
// which is available at https://www.eclipse.org/legal/epl-2.0/
//
// SPDX-License-Identifier: EPL-2.0
//
// Contributors:
//   Red Hat, Inc. - initial API and implementation
//
package util

import (
	"testing"

	appsv1 "k8s.io/api/apps/v1"
	"k8s.io/apimachinery/pkg/api/resource"
)

type TestExpectedResources struct {
	MemoryLimit   string
	MemoryRequest string
	CpuRequest    string
	CpuLimit      string
}

func CompareResources(actualDeployment *appsv1.Deployment, expected TestExpectedResources, t *testing.T) {
	compareQuantity(
		"Memory limits",
		actualDeployment.Spec.Template.Spec.Containers[0].Resources.Limits.Memory(),
		expected.MemoryLimit,
		t,
	)

	compareQuantity(
		"Memory requests",
		actualDeployment.Spec.Template.Spec.Containers[0].Resources.Requests.Memory(),
		expected.MemoryRequest,
		t,
	)

	compareQuantity(
		"CPU limits",
		actualDeployment.Spec.Template.Spec.Containers[0].Resources.Limits.Cpu(),
		expected.CpuLimit,
		t,
	)

	compareQuantity(
		"CPU requests",
		actualDeployment.Spec.Template.Spec.Containers[0].Resources.Requests.Cpu(),
		expected.CpuRequest,
		t,
	)
}

func ValidateSecurityContext(actualDeployment *appsv1.Deployment, t *testing.T) {
	if actualDeployment.Spec.Template.Spec.Containers[0].SecurityContext.Capabilities.Drop[0] != "ALL" {
		t.Error("Deployment doesn't contain 'Capabilities Drop ALL' in a SecurityContext")
	}
}

func compareQuantity(resource string, actualQuantity *resource.Quantity, expected string, t *testing.T) {
	expectedQuantity := GetResourceQuantity(expected, expected)
	if !actualQuantity.Equal(expectedQuantity) {
		t.Errorf("%s: expected %s, actual %s", resource, expectedQuantity.String(), actualQuantity.String())
	}
}
