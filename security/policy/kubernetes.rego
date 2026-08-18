# Policy as code for Kubernetes manifests.
#   conftest test --policy security/policy k8s/base/*.yaml
#
# These encode the pod security baseline. Every rule here has a corresponding
# Kyverno policy in security/kyverno/ - the difference being that Conftest
# blocks at CI time and Kyverno blocks at admission time. Teaching both makes
# the "shift left AND enforce at the gate" point concrete rather than abstract.

package main

import rego.v1

# Pod spec regardless of workload kind. CronJob nests the pod one level deeper
# (spec.jobTemplate.spec.template.spec); everything else uses spec.template.spec.
pod_spec := input.spec.template.spec if {
	input.kind in {"Deployment", "StatefulSet", "DaemonSet", "Job"}
}

pod_spec := input.spec.jobTemplate.spec.template.spec if {
	input.kind == "CronJob"
}

# Security rules check MAIN and INIT containers alike - a privileged
# initContainer is still privileged, and used to slip through unchecked.
containers contains c if {
	some c in pod_spec.containers
}

containers contains c if {
	some c in pod_spec.initContainers
}

# --- deny: privilege escalation --------------------------------------------
deny contains msg if {
	some c in containers
	c.securityContext.allowPrivilegeEscalation != false
	msg := sprintf("%s/%s container '%s' must set allowPrivilegeEscalation: false", [input.kind, input.metadata.name, c.name])
}

# --- deny: no resource limits ----------------------------------------------
deny contains msg if {
	some c in containers
	not c.resources.limits.memory
	msg := sprintf("container '%s' has no memory limit. One leaking pod can evict every other pod on the node.", [c.name])
}

deny contains msg if {
	some c in containers
	not c.resources.requests.cpu
	msg := sprintf("container '%s' has no CPU request. The scheduler is guessing.", [c.name])
}

# --- deny: mutable tags in production -------------------------------------
deny contains msg if {
	some c in containers
	endswith(c.image, ":latest")
	msg := sprintf("container '%s' uses :latest. You cannot roll back to a tag that moves.", [c.name])
}

# --- deny: missing probes -------------------------------------------------
# Only long-running, traffic-serving workloads need a readinessProbe. Init
# containers and run-to-completion pods (Job/CronJob) legitimately have none.
deny contains msg if {
	input.kind in {"Deployment", "StatefulSet", "DaemonSet"}
	some c in input.spec.template.spec.containers
	not c.readinessProbe
	msg := sprintf("container '%s' has no readinessProbe. Kubernetes will send traffic to a pod that is not ready.", [c.name])
}

# --- warn: writable root filesystem ---------------------------------------
warn contains msg if {
	some c in containers
	not c.securityContext.readOnlyRootFilesystem
	msg := sprintf("container '%s' has a writable root filesystem. Set readOnlyRootFilesystem: true and mount an emptyDir for /tmp.", [c.name])
}

# --- warn: capabilities not dropped ---------------------------------------
warn contains msg if {
	some c in containers
	not c.securityContext.capabilities.drop
	msg := sprintf("container '%s' does not drop capabilities. Start from drop: [ALL] and add back only what breaks.", [c.name])
}

# --- deny: hardcoded secret values ----------------------------------------
deny contains msg if {
	input.kind == "Secret"
	input.stringData
	not input.metadata.annotations["daig.tkxel/teaching-artifact"]
	msg := "Secret with inline stringData. Use External Secrets or a CSI driver. If this is a labelled teaching artifact, annotate it as one."
}
