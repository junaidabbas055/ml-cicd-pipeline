terraform {
  required_version = ">= 1.6"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

# Nova compute instance with anti-affinity and security groups
resource "openstack_compute_instance_v2" "this" {
  count           = var.instance_count
  name            = "${var.name}-${count.index + 1}"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = var.key_pair
  security_groups = var.security_groups

  metadata = {
    environment = var.environment
    managed-by  = "terraform"
    role        = var.role
  }

  network {
    name = var.network_name
  }

  scheduler_hints {
    group = openstack_compute_servergroup_v2.anti_affinity.id
  }

  user_data = var.user_data

  lifecycle {
    ignore_changes = [image_name]
  }
}

resource "openstack_compute_servergroup_v2" "anti_affinity" {
  name     = "${var.name}-anti-affinity"
  policies = ["anti-affinity"]
}

resource "openstack_compute_floatingip_associate_v2" "this" {
  count       = var.assign_floating_ip ? var.instance_count : 0
  floating_ip = openstack_networking_floatingip_v2.this[count.index].address
  instance_id = openstack_compute_instance_v2.this[count.index].id
}

resource "openstack_networking_floatingip_v2" "this" {
  count = var.assign_floating_ip ? var.instance_count : 0
  pool  = var.floating_ip_pool
}

# Block storage volumes
resource "openstack_blockstorage_volume_v3" "data" {
  count       = var.data_volume_size > 0 ? var.instance_count : 0
  name        = "${var.name}-${count.index + 1}-data"
  size        = var.data_volume_size
  volume_type = var.volume_type
}

resource "openstack_compute_volume_attach_v2" "data" {
  count       = var.data_volume_size > 0 ? var.instance_count : 0
  instance_id = openstack_compute_instance_v2.this[count.index].id
  volume_id   = openstack_blockstorage_volume_v3.data[count.index].id
}
