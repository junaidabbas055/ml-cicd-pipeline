terraform {
  required_version = ">= 1.6"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }

  backend "swift" {
    container         = "terraform-state"
    state_name        = "prod/openstack-infra.tfstate"
    archive_container = "terraform-state-archive"
  }
}

provider "openstack" {
  cloud = "prodcloud"
}

locals {
  prefix = "infra-prod"
}

module "identity" {
  source       = "../../modules/identity"
  project_name = "${local.prefix}-project"
  environment  = "prod"

  service_accounts = {
    cicd-bot = {
      password = var.cicd_bot_password
      email    = "cicd-bot@example.com"
    }
    monitoring-bot = {
      password = var.monitoring_bot_password
      email    = "monitoring@example.com"
    }
  }

  custom_roles     = ["deployer", "viewer", "monitoring"]
  role_assignments = [
    { user = "cicd-bot",       role = "deployer"   },
    { user = "monitoring-bot", role = "monitoring"  },
  ]
}

module "network" {
  source       = "../../modules/network"
  prefix       = local.prefix
  subnet_cidr  = "192.168.20.0/24"
  bastion_cidr = var.bastion_cidr
}

module "compute_app" {
  source           = "../../modules/compute"
  name             = "${local.prefix}-app"
  environment      = "prod"
  role             = "app"
  instance_count   = 4
  flavor_name      = "m1.xlarge"
  image_name       = "Ubuntu-22.04"
  key_pair         = var.key_pair
  network_name     = module.network.network_name
  security_groups  = [module.network.base_sg_id, module.network.web_sg_id]
  data_volume_size = 100
}

module "compute_db" {
  source           = "../../modules/compute"
  name             = "${local.prefix}-db"
  environment      = "prod"
  role             = "database"
  instance_count   = 2
  flavor_name      = "m1.2xlarge"
  image_name       = "Ubuntu-22.04"
  key_pair         = var.key_pair
  network_name     = module.network.network_name
  security_groups  = [module.network.base_sg_id]
  data_volume_size = 500
  volume_type      = "ceph-ssd"
}
