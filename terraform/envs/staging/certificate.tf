# Stage 2 of 3: ask Azure for a free managed certificate for the hostname.
# Azure proves we own the name by following the CNAME we created, so the
# hostname has to be registered on the app first (stage 1, already done).
# Stage 3 binds this certificate to the hostname.
resource "azurerm_container_app_environment_managed_certificate" "staging" {
  name                         = "cert-staging"
  container_app_environment_id = azapi_resource.env.id
  subject_name                 = "staging.desksharkproject.me"
  domain_control_validation    = "CNAME"

  depends_on = [azurerm_container_app_custom_domain.staging]
}