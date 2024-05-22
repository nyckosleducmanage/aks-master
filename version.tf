# Azure Provider source and version being used
terraform {
  required_version = ">= 0.12.0"
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">=2.59.0"
      configuration_aliases = [azurerm.servicespartages]
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
  }
}
