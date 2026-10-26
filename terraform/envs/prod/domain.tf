# Register the hostname on the app. The certificate is bound separately in
# binding.tf, because the azurerm provider only accepts "certificates/..." IDs
# and managed certificates have "managedCertificates/..." IDs.
resource "azurerm_container_app_custom_domain" "app" {
  name                     = "app.desksharkproject.me"
  container_app_id         = azurerm_container_app.deskshark.id
  certificate_binding_type = "Disabled"

  # After the certificate is bound, Azure changes these two values. Without
  # this, Terraform would try to put them back and switch HTTPS off.
  lifecycle {
    ignore_changes = [
      certificate_binding_type,
      container_app_environment_certificate_id,
    ]
  }

  depends_on = [
    azurerm_dns_cname_record.app,
    azurerm_dns_txt_record.app_verify,
  ]
}