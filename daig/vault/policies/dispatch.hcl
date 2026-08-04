# Policy for the dispatch service. Narrowest of the three.

path "daig/data/database" {
  capabilities = ["read"]
}

path "daig-db/creds/dispatch" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "daig/data/app" {
  capabilities = ["deny"]
}

path "daig/data/payment" {
  capabilities = ["deny"]
}
