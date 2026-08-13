# TIER 3 - PostgreSQL Flexible Server, private, no public endpoint.

resource "random_password" "db" {
  length  = 32
  special = true
  # Azure rejects several characters in this position; constrain rather than
  # discover it at apply time.
  override_special = "!#%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${local.name}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  version                       = "16"
  sku_name                      = var.db_sku
  storage_mb                    = 32768
  auto_grow_enabled             = true
  public_network_access_enabled = false

  administrator_login    = "daigadmin"
  administrator_password = random_password.db.result

  delegated_subnet_id = azurerm_subnet.data.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  backup_retention_days        = var.environment == "prod" ? 14 : 7
  geo_redundant_backup_enabled = var.environment == "prod"

  zone = "1"

  tags = local.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_database" "daig" {
  name      = "daig"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_slow" {
  name      = "log_min_duration_statement"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "500"
}

# ---------------- secrets ----------------
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "kv-daig-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = var.environment == "prod"
  enable_rbac_authorization  = true
  tags                       = local.tags
}

resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "db_url" {
  name         = "database-url"
  key_vault_id = azurerm_key_vault.main.id
  value = format(
    "postgresql://daigadmin:%s@%s:5432/daig?sslmode=require",
    urlencode(random_password.db.result),
    azurerm_postgresql_flexible_server.main.fqdn
  )

  depends_on = [azurerm_role_assignment.kv_admin]
}
