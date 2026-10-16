locals {
  location = "eastasia"

  # Placeholder until DeskShark's own image is in the registry
  image       = "mcr.microsoft.com/k8se/quickstart:latest"
  target_port = 80

  tags = {
    app   = "deskshark"
    env   = "staging"
    owner = "henryyy"
  }
}

data "azurerm_resource_group" "this" {
  name = "rg-dsk-staging"
}

# The registry was built by the shared stack, so we only read it here.
data "azurerm_container_registry" "shared" {
  name                = "crdskf2500b"
  resource_group_name = "rg-dsk-shared"
}

# Where the app's logs go. The daily cap protects the student credit.
resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-dsk-staging"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
  tags                = local.tags
}

# The shared "hosting space" that Container Apps run inside.
resource "azurerm_container_app_environment" "this" {
  name                       = "cae-dsk-staging"
  location                   = local.location
  resource_group_name        = data.azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = local.tags
}

# The app's own identity, so it can pull images without a password.
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-dsk-staging-app"
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

resource "azurerm_container_app" "deskshark" {
  name                         = "ca-deskshark-staging"
  container_app_environment_id = azurerm_container_app_environment.this.id
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

  template {
    min_replicas = 0 # scales to zero when idle, so staging costs almost nothing
    max_replicas = 1

    container {
      name   = "deskshark"
      image  = local.image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = local.target_port

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  depends_on = [azurerm_role_assignment.acr_pull]
}

output "app_url" {
  value = "https://${azurerm_container_app.deskshark.ingress[0].fqdn}"
}