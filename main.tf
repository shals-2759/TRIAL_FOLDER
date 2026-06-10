terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "test" {
  name     = "rg-infracost-test"
  location = "East US"
}

resource "azurerm_storage_account" "test" {
  name                     = "infracosttest12345"
  resource_group_name      = azurerm_resource_group.test.name
  location                 = azurerm_resource_group.test.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security improvement (already correct)
  public_network_access_enabled = false

  # Required FinOps tags (fixes tagging policy issue)
  tags = {
    Service     = "Storage"
    Environment = "Dev"
  }

  blob_properties {
    last_access_time_enabled = true
  }
}

# Lifecycle policy (fixes governance recommendation)
resource "azurerm_storage_management_policy" "test" {
  storage_account_id = azurerm_storage_account.test.id

  rule {
    name    = "cleanup-rule"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 365
      }
    }
  }
}