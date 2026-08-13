# Policy as code for Terraform plans.
#   terraform show -json tfplan > plan.json
#   conftest test --policy security/policy plan.json
#
# tfsec and Checkov cover the generic cases. This file is for OUR rules - the
# ones no vendor ships because they are specific to how tkxel works.

package main

import rego.v1

resources contains r if {
	some r in input.resource_changes
	"create" in r.change.actions
}

resources contains r if {
	some r in input.resource_changes
	"update" in r.change.actions
}

# --- deny: SSH from anywhere ----------------------------------------------
deny contains msg if {
	some r in resources
	r.type == "aws_security_group"
	some rule in r.change.after.ingress
	rule.from_port <= 22
	rule.to_port >= 22
	"0.0.0.0/0" in rule.cidr_blocks
	msg := sprintf("%s allows SSH from 0.0.0.0/0. Use SSM Session Manager or a bastion.", [r.address])
}

# --- deny: publicly accessible database ----------------------------------
deny contains msg if {
	some r in resources
	r.type == "aws_db_instance"
	r.change.after.publicly_accessible == true
	msg := sprintf("%s is publicly accessible. A database belongs in a private subnet.", [r.address])
}

deny contains msg if {
	some r in resources
	r.type == "aws_db_instance"
	r.change.after.storage_encrypted != true
	msg := sprintf("%s has unencrypted storage. Encryption at rest costs nothing here.", [r.address])
}

# --- deny: unencrypted S3 / public bucket --------------------------------
deny contains msg if {
	some r in resources
	r.type == "aws_s3_bucket_public_access_block"
	r.change.after.block_public_acls != true
	msg := sprintf("%s does not block public ACLs.", [r.address])
}

# --- tkxel convention: every resource must carry cost attribution --------
deny contains msg if {
	some r in resources
	startswith(r.type, "aws_")
	tags := object.get(r.change.after, "tags", {})
	not tags.CostCentre
	msg := sprintf("%s has no CostCentre tag. Untagged spend cannot be attributed, which is a FinOps failure before it is a security one.", [r.address])
}
