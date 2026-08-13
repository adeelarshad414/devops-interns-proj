terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # backend "azurerm" {
  #   resource_group_name  = "tkxel-tfstate"
  #   storage_account_name = "tkxeldaigtfstate"
  #   container_name       = "tfstate"
  #   key                  = "azure/daig.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      # Refuse to delete a resource group that still contains resources.
      # The default is to take everything with it, which is how people lose
      # things they did not know were in there.
      prevent_deletion_if_contains_resources = true
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
