resource "azurerm_storage_account" "uploads" {
  name                            = "stdskuploadsprodf2500b"
  resource_group_name             = data.azurerm_resource_group.this.name
  location                        = local.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_share" "uploads" {
  name               = "uploads"
  storage_account_id = azurerm_storage_account.uploads.id
  quota              = 5
}

resource "azurerm_container_app_environment_storage" "uploads" {
  name                         = "uploads"
  container_app_environment_id = azapi_resource.env.id
  account_name                 = azurerm_storage_account.uploads.name
  share_name                   = azurerm_storage_share.uploads.name
  access_key                   = azurerm_storage_account.uploads.primary_access_key
  access_mode                  = "ReadWrite"
}