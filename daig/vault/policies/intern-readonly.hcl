# Policy for interns during the rotation.
#
# They can see that secrets exist and read the metadata, but not the values.
# This is deliberately the shape of a real production policy: engineers usually
# need to know what secrets exist and when they were last rotated far more often
# than they need the values.

path "daig/metadata/*" {
  capabilities = ["list", "read"]
}

path "daig/data/*" {
  capabilities = ["deny"]
}

# They can read the policies themselves. Understanding what you are allowed to
# do should not itself be privileged.
path "sys/policies/acl" {
  capabilities = ["list"]
}

path "sys/policies/acl/*" {
  capabilities = ["read"]
}
