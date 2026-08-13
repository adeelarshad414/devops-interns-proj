# Policy for the kitchen service. Narrower than orders - kitchen never touches
# payment or customer data, so it gets less.

path "daig/data/database" {
  capabilities = ["read"]
}

path "daig-db/creds/kitchen" {
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
