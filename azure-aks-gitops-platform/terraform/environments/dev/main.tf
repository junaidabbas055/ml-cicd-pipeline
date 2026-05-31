terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatedev001"
    container_name       = "tfstate"
    key                  = "dev/aks-platform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "this" {
  name     = "aks-platform-dev-rg"
  location = var.location
  tags     = local.tags
}

locals {
  prefix = "aksdev"
  tags = {
    environment = "dev"
    managed-by  = "terraform"
    project     = "aks-gitops-platform"
  }
}

module "networking" {
  source              = "../../modules/networking"
  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
  bastion_subnet_cidr = var.bastion_subnet_cidr
  tags                = local.tags
}

module "aks" {
  source              = "../../modules/aks-cluster"
  cluster_name        = "${local.prefix}-cluster"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = local.prefix
  kubernetes_version  = var.kubernetes_version
  environment         = "dev"

  system_node_count = 2
  system_min_count  = 2
  system_max_count  = 4
  system_vm_size    = "Standard_D4s_v3"

  workload_vm_size    = "Standard_D4s_v3"
  workload_min_count  = 1
  workload_max_count  = 8

  log_analytics_workspace_id = module.networking.log_analytics_workspace_id
  aad_admin_group_ids        = var.aad_admin_group_ids
  tags                       = local.tags
}

module "monitoring" {
  source              = "../../modules/monitoring"
  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.this.name
  aks_cluster_id      = module.aks.cluster_id
  alert_email         = var.alert_email
}
