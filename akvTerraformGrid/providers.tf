terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # <<< Add these two lines >>>
  subscription_id = "fc1f1d7c-bc1f-4378-933e-0e1ea09b5f4b"
  tenant_id       = "fca47690-ab7d-413c-90e4-aafd92aac945"
}