# Policy as code for Dockerfiles.
#   conftest test --policy security/policy services/*/Dockerfile
#
# The idea worth teaching: these are the rules your team already has, written
# down in a form a machine can check. A rule in a wiki page is a suggestion; a
# rule in CI is a standard.

package main

import rego.v1

# --- deny: must not run as root -------------------------------------------
deny contains msg if {
	input[i].Cmd == "from"
	not has_user_instruction
	msg := "Dockerfile does not set USER. Containers must not run as root (CWE-250)."
}

has_user_instruction if {
	input[_].Cmd == "user"
}

# --- deny: no :latest base images -----------------------------------------
deny contains msg if {
	some i
	input[i].Cmd == "from"
	val := input[i].Value[0]
	endswith(val, ":latest")
	msg := sprintf("Base image '%s' uses :latest. Pin a version - a tag that can move is not reproducible.", [val])
}

deny contains msg if {
	some i
	input[i].Cmd == "from"
	val := input[i].Value[0]
	not contains(val, ":")
	not contains(val, " as ")
	msg := sprintf("Base image '%s' has no tag, which means :latest.", [val])
}

# --- warn: no healthcheck --------------------------------------------------
warn contains msg if {
	not has_healthcheck
	msg := "No HEALTHCHECK. Your orchestrator cannot tell 'running' from 'working'."
}

has_healthcheck if {
	input[_].Cmd == "healthcheck"
}

# --- deny: secrets in ARG or ENV ------------------------------------------
deny contains msg if {
	some i
	input[i].Cmd in {"env", "arg"}
	val := lower(concat(" ", input[i].Value))
	some pattern in ["password", "secret", "token", "api_key", "apikey", "private_key"]
	contains(val, pattern)
	not contains(val, "change_me_dev_only")
	msg := sprintf("Possible secret in %s: %v. Build args and ENV are visible in image history forever.", [upper(input[i].Cmd), input[i].Value])
}

# --- warn: apt/apk without cache cleanup ----------------------------------
warn contains msg if {
	some i
	input[i].Cmd == "run"
	val := concat(" ", input[i].Value)
	contains(val, "apk add")
	not contains(val, "--no-cache")
	msg := "apk add without --no-cache leaves the index in the layer."
}
