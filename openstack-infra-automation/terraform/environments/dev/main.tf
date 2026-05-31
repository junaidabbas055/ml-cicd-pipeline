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
    state_name        = "dev/openstack-infra.tfstate"
    archive_container = "terraform-state-archive"
  }
}

provider "openstack" {
  cloud = "devcloud"   # references ~/.config/openstack/clouds.yaml
}

locals {
  prefix = "infra-dev"
  tags = {
    environment = "dev"
    managed-by  = "terraform"
    project     = "openstack-infra-automation"
  }
}

module "identity" {
  source       = "../../modules/identity"
  project_name = "${local.prefix}-project"
  environment  = "dev"

  service_accounts = {
    cicd-bot = {
      password = var.cicd_bot_password
      email    = "cicd-bot@example.com"
    }
  }

  custom_roles     = ["deployer", "viewer"]
  role_assignments = [{ user = "cicd-bot", role = "deployer" }]
}

module "network" {
  source      = "../../modules/network"
  prefix      = local.prefix
  subnet_cidr = "192.168.10.0/24"
  bastion_cidr = var.bastion_cidr
}

module "compute_app" {
  source          = "../../modules/compute"
  name            = "${local.prefix}-app"
  environment     = "dev"
  role            = "app"
  instance_count  = 2
  flavor_name     = "m1.medium"
  image_name      = "Ubuntu-22.04"
  key_pair        = var.key_pair
  network_name    = module.network.network_name
  security_groups = [module.network.base_sg_id, module.network.web_sg_id]
  data_volume_size = 50
}

module "compute_db" {
  source          = "../../modules/compute"
  name            = "${local.prefix}-db"
  environment     = "dev"
  role            = "database"
  instance_count  = 1
  flavor_name     = "m1.large"
  image_name      = "Ubuntu-22.04"
  key_pair        = var.key_pair
  network_name    = module.network.network_name
  security_groups = [module.network.base_sg_id]
  data_volume_size = 200
  volume_type      = "ceph-ssd"
}
