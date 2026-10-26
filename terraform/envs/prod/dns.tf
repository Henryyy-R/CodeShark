# The zone was created during setup and delegated from Namecheap,
# so Terraform only reads it and adds records to it.
data "azurerm_dns_zone" "main" {
  name                = "desksharkproject.me"
  resource_group_name = "rg-dsk-shared"
}

# app.desksharkproject.me -> the app's Azure address
resource "azurerm_dns_cname_record" "app" {
  name                = "app"
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 300
  record              = azurerm_container_app.deskshark.ingress[0].fqdn
  tags                = local.tags
}

# Proof of ownership that Azure checks before it accepts the custom domain.
# The verification ID is a public domain-ownership token, not a credential.
resource "azurerm_dns_txt_record" "app_verify" {
  name                = "asuid.app"
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 300

  record {
    value = nonsensitive(azurerm_container_app.deskshark.custom_domain_verification_id)
  }

  tags = local.tags
}