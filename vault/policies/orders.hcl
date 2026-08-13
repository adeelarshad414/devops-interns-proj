# Policy for the orders service.
#
# Least privilege, written down. Orders reads its own database credentials and
# the shared application secrets. Nothing else. It cannot read the payment
# provider key, it cannot write anything, and it cannot list what else exists.
#
# The test of a good policy is not "does the service work" - it is "what happens
# when this service is compromised". Read it with that question in mind.

path "daig/data/database" {
  capabilities = ["read"]
}

path "daig/data/app" {
  capabilities = ["read"]
}

# Dynamic database credentials. Orders may mint a short-lived PostgreSQL user
# for itself and nothing else.
path "daig-db/creds/orders" {
  capabilities = ["read"]
}

# A service must be able to renew and revoke its own leases, or a dynamic
# credential expires mid-request and the service cannot do anything about it.
path "sys/leases/renew" {
  capabilities = ["update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Explicitly denied. Deny always wins in OpenBao, so writing this down protects
# against a future broad grant elsewhere accidentally including it.
path "daig/data/payment" {
  capabilities = ["deny"]
}

path "sys/*" {
  capabilities = ["deny"]
}
