locals {
  location    = "eastasia"
  image       = "${data.azurerm_container_registry.shared.login_server}/deskshark:${local.image_tag}"
  target_port = 5000

  tags = {
    app   = "deskshark"
    env   = "prod"
    owner = "henryyy"
  }
}

data "azurerm_resource_group" "this" {
  name = "rg-dsk-prod"
}

# The registry was built by the shared stack, so we only read it here.
data "azurerm_container_registry" "shared" {
  name                = "crdskf2500b"
  resource_group_name = "rg-dsk-shared"
}

# The production Key Vault was created during setup. Its secrets are added by hand.
data "azurerm_key_vault" "prod" {
  name                = "kv-dsk-prod-f2500b"
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-dsk-prod"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
  tags                = local.tags
}

# A STANDARD (consumption-only) environment, requested explicitly because the
# default in this subscription is Express, which has no Key Vault references,
# no custom domains and no Azure Files.
resource "azapi_resource" "env" {
  type      = "Microsoft.App/managedEnvironments@2026-07-01"
  name      = "cae-dsk-prod"
  parent_id = data.azurerm_resource_group.this.id
  location  = local.location
  tags      = local.tags

  # The newest API version may be newer than the provider's built-in schema.
  schema_validation_enabled = false

  body = {
    properties = {
      environmentMode = "ConsumptionOnly"
    }
  }
}

# The app's own identity, so it can pull images and read secrets without a password.
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-dsk-prod-app"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = data.azurerm_container_registry.shared.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "kv_secrets" {
  scope                = data.azurerm_key_vault.prod.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_container_app" "deskshark" {
  name                         = "ca-deskshark-prod"
  container_app_environment_id = azapi_resource.env.id
  resource_group_name          = data.azurerm_resource_group.this.name
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = data.azurerm_container_registry.shared.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  # Secrets are read from Key Vault by the app's own identity.
  # Terraform never sees the values.
  secret {
    name                = "mongo-uri"
    key_vault_secret_id = "${data.azurerm_key_vault.prod.vault_uri}secrets/mongo-uri"
    identity            = azurerm_user_assigned_identity.app.id
  }

  secret {
    name                = "clerk-secret-key"
    key_vault_secret_id = "${data.azurerm_key_vault.prod.vault_uri}secrets/clerk-secret-key"
    identity            = azurerm_user_assigned_identity.app.id
  }

  secret {
    name                = "clerk-publishable-key"
    key_vault_secret_id = "${data.azurerm_key_vault.prod.vault_uri}secrets/clerk-publishable-key"
    identity            = azurerm_user_assigned_identity.app.id
  }

  template {
    # Always on: the ticket monitor cron runs inside the app process.
    min_replicas = 1
    max_replicas = 1

    # Azure adds this default scaler itself, so we state it explicitly.
    http_scale_rule {
      name                = "http-scaler"
      concurrent_requests = "10"
    }

    volume {
      name          = "uploads"
      storage_type  = "AzureFile"
      storage_name  = azurerm_container_app_environment_storage.uploads.name
      mount_options = "uid=1000,gid=1000,dir_mode=0770,file_mode=0660"
    }

    container {
      name   = "deskshark"
      image  = local.image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "PORT"
        value = "5000"
      }

      env {
        name        = "MONGO_URI"
        secret_name = "mongo-uri"
      }

      env {
        name        = "CLERK_SECRET_KEY"
        secret_name = "clerk-secret-key"
      }

      env {
        name        = "CLERK_PUBLISHABLE_KEY"
        secret_name = "clerk-publishable-key"
      }

      volume_mounts {
        name = "uploads"
        path = "/app/backend/uploads"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = local.target_port
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  # Azure doesn't report these back for a single-revision app, so the
  # provider would show a permanent difference.
  lifecycle {
    ignore_changes = [
      ingress[0].traffic_weight,
      template[0].cooldown_period_in_seconds,
      template[0].polling_interval_in_seconds,
    ]
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.kv_secrets,
  ]
}

output "app_url" {
  value = "https://${azurerm_container_app.deskshark.ingress[0].fqdn}"
}