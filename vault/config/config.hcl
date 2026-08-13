# OpenBao server configuration.
#
# Every setting below is annotated with what it would be in production, because
# the difference between this file and a production one is most of the learning.

ui = true

storage "file" {
  path = "/openbao/data"
  # PRODUCTION: "raft" for integrated storage with 3 or 5 nodes, or a supported
  # external backend. File storage is single-node and has no HA story at all.
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
  # PRODUCTION: never. Terminate TLS here with a real certificate. Plaintext
  # means every token and every secret crosses the network in the clear.
}

# Where clients are told to reach this node.
api_addr     = "http://openbao:8200"
cluster_addr = "http://openbao:8201"

# Audit log. Every read of every secret, appended.
#
# This is the answer to "who read the production database password, and when".
# Without it, a leaked credential is an unbounded investigation. With it, it is
# a grep. Turn it on before you need it.
#
# Enabled at runtime by vault/bootstrap.sh rather than here, because OpenBao
# refuses to start if it cannot write the audit device - and a vault that will
# not start because of logging is its own outage.

disable_mlock = false

# PRODUCTION also wants:
#   seal "awskms" { ... }        auto-unseal, so a restart does not need a human
#   telemetry { ... }            Prometheus metrics for lease counts and latency
#   log_level = "info"
#   max_lease_ttl / default_lease_ttl tuned deliberately
