# Stage 2 of 3: ask Azure for a free managed certificate for the hostname.
# Azure proves we own the name by following the CNAME we created, so the
# hostname has to be registered on the app first (stage 1, already done).
# Stage 3 binds this certificate to the hostname.
# The certificate is created inside the shared environment, which the staging
# stack owns, so it is named separately from staging's "cert-staging".
resource "azurerm_container_app_environment_managed_certificate" "app" {
  name                         = "cert-prod"
  container_app_environment_id = local.env_id
  subject_name                 = "app.desksharkproject.me"
  domain_control_validation    = "CNAME"

  depends_on = [azurerm_container_app_custom_domain.app]
}