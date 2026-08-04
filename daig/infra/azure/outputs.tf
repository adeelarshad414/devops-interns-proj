output "application_url" {
  value = "https://${azurerm_container_app.service["orders"].ingress[0].fqdn}"
}

output "database_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "key_vault" {
  value = azurerm_key_vault.main.name
}

output "registry" {
  value = azurerm_container_registry.main.login_server
}

output "log_analytics_workspace" {
  value = azurerm_log_analytics_workspace.main.name
}

output "cost_note" {
  value = join(" ", [
    "PostgreSQL Flexible Server and the Container Apps environment both bill",
    "continuously. Log Analytics bills per GB ingested, which surprises people.",
    "Monthly figures derive from 730 hours. terraform destroy when you finish."
  ])
}
