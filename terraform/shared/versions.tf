terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Terraform's state lives in the storage account we created earlier
  backend "azurerm" {
    resource_group_name  = "rg-dsk-tfstate"
    storage_account_name = "stdsktfstatef2500b"
    container_name       = "tfstate"
    key                  = "shared.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}

  # We already switched on the Azure services we need, so don't let
  # Terraform try to register them itself.
  resource_provider_registrations = "none"
}