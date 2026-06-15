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
  
tags = {
    Service     = "StorageApp"   # any meaningful service name
    Environment = "Dev"          # must be Dev / Stage / Prod
  }

}