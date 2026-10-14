data "azurerm_resource_group" "shared" {
  name = "rg-dsk-shared"
}

# The DNS zone was created by hand during setup, so Terraform only reads it.
data "azurerm_dns_zone" "main" {
  name                = "desksharkproject.me"
  resource_group_name = data.azurerm_resource_group.shared.name
}

# One Standard registry is free on the student plan. Don't create a second.
resource "azurerm_container_registry" "main" {
  name                = "crdskf2500b"
  resource_group_name = data.azurerm_resource_group.shared.name
  location            = data.azurerm_resource_group.shared.location
  sku                 = "Standard"
  admin_enabled       = false

  tags = {
    app   = "deskshark"
    env   = "shared"
    owner = "henryyy"
  }
}

output "acr_id" {
  value = azurerm_container_registry.main.id
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "dns_zone_name" {
  value = data.azurerm_dns_zone.main.name
}