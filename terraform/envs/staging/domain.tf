# Stage 1 of 3: register the hostname on the app, without a certificate.
# Azure checks the CNAME and the asuid TXT record before it accepts this.
# Stage 2 creates the free managed certificate; stage 3 binds it.
resource "azurerm_container_app_custom_domain" "staging" {
  name                     = "staging.desksharkproject.me"
  container_app_id         = azurerm_container_app.deskshark.id
  certificate_binding_type = "Disabled"

  depends_on = [
    azurerm_dns_cname_record.staging,
    azurerm_dns_txt_record.staging_verify,
  ]
}