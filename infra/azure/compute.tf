# TIER 2 - Container Apps. Managed Kubernetes underneath without exposing it,
# which makes it a reasonable comparison point for Friday: same primitives
# (revisions, replicas, probes, traffic splitting), far less surface area.

resource "azurerm_user_assigned_identity" "apps" {
  name                = "id-${local.name}-apps"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.apps.principal_id
}

resource "azurerm_role_assignment" "kv_read" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.apps.principal_id
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.name}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id   = azurerm_subnet.apps.id
  tags                       = local.tags
}

resource "azurerm_container_app" "service" {
  for_each = var.services

  name                         = "ca-${each.key}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.apps.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.apps.id
  }

  secret {
    name                = "database-url"
    key_vault_secret_id = azurerm_key_vault_secret.db_url.id
    identity            = azurerm_user_assigned_identity.apps.id
  }

  ingress {
    external_enabled = each.value.external
    target_port      = each.value.port
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = each.value.min_replicas
    max_replicas = each.value.max_replicas

    container {
      name   = each.key
      image  = "${azurerm_container_registry.main.login_server}/daig/${each.key}:latest"
      cpu    = each.value.cpu
      memory = each.value.memory

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "PORT"
        value = tostring(each.value.port)
      }

      env {
        name  = "KITCHEN_URL"
        value = "https://ca-kitchen.internal.${azurerm_container_app_environment.main.default_domain}"
      }

      env {
        name  = "DISPATCH_URL"
        value = "https://ca-dispatch.internal.${azurerm_container_app_environment.main.default_domain}"
      }

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/healthz"
        port      = each.value.port
        # Liveness must not depend on the database - see the Kubernetes
        # manifests for the same reasoning stated at length.
        initial_delay    = 10
        interval_seconds = 30
      }

      readiness_probe {
        transport        = "HTTP"
        path             = "/readyz"
        port             = each.value.port
        interval_seconds = 10
      }
    }

    # Scale on concurrent requests rather than CPU. For the iftar spike,
    # request depth is the leading indicator; CPU is a lagging one.
    http_scale_rule {
      name                = "concurrent-requests"
      concurrent_requests = 50
    }
  }
}
