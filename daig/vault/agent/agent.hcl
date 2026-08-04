# OpenBao Agent - the sidecar alternative to in-app integration.
#
# TWO WAYS TO GET A SECRET INTO A SERVICE, and the choice is a real one:
#
#   A. In-app (services/_shared/secrets.js)
#      The application authenticates and reads directly.
#      + the app knows when a credential rotates and can react
#      + no extra process
#      - every service needs vault client code
#      - the vault becomes a hard startup dependency
#
#   B. Agent sidecar (this file)
#      A sidecar authenticates, renders a template, and the app reads a file
#      or environment variable knowing nothing about any vault.
#      + zero application changes; works for anything, including closed source
#      + the agent handles renewal, caching and retry
#      - a rotated secret needs a restart or a file-watching app
#      - one more process per service
//
# Daig ships A wired up and B configured but not enabled, so interns can compare
# them. Ask which they would choose for a legacy Java service they cannot modify.
# The answer is obviously B, and arriving at it themselves is the point.

pid_file = "/tmp/agent.pid"

vault {
  address = "http://openbao:8200"
  retry {
    num_retries = 5
  }
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path                   = "/etc/bao/role_id"
      secret_id_file_path                 = "/etc/bao/secret_id"
      remove_secret_id_file_after_reading = false
    }
  }

  # The agent writes its token here so other tooling on the host can use it
  # without re-authenticating.
  sink "file" {
    config = {
      path = "/tmp/bao-token"
      mode = 0640
    }
  }
}

# Caching means a hundred reads become one round trip, and the agent serves
# stale-but-valid values if the vault briefly becomes unreachable. That second
# property is why an agent makes the vault a soft dependency instead of a hard one.
cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address     = "127.0.0.1:8100"
  tls_disable = true
}

# Render the credentials into an env file the application can source.
template {
  source      = "/etc/bao/templates/daig.env.ctmpl"
  destination = "/etc/daig/secrets.env"
  perms       = 0640

  # Restart the application when the rendered output changes. This is how a
  # rotated secret reaches a process that only reads its configuration at boot.
  exec {
    command = ["/bin/sh", "-c", "kill -HUP $(cat /tmp/app.pid) || true"]
  }
}
