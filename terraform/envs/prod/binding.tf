# Stage 3 of 3: bind the managed certificate (certificate.tf) to the hostname
# (domain.tf). This sends the raw API request: customDomains[].certificateId
# takes the managedCertificates ID directly.
resource "azapi_update_resource" "app_binding" {
  type        = "Microsoft.App/containerApps@2025-01-01"
  resource_id = azurerm_container_app.deskshark.id

  body = {
    properties = {
      configuration = {
        ingress = {
          customDomains = [
            {
              name          = "app.desksharkproject.me"
              bindingType   = "SniEnabled"
              certificateId = azurerm_container_app_environment_managed_certificate.app.id
            }
          ]
        }
      }
    }
  }

  depends_on = [azurerm_container_app_custom_domain.app]
}