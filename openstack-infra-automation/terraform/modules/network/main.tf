terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

# Neutron network + subnet
resource "openstack_networking_network_v2" "this" {
  name                  = "${var.prefix}-network"
  admin_state_up        = true
  port_security_enabled = true
}

resource "openstack_networking_subnet_v2" "this" {
  name            = "${var.prefix}-subnet"
  network_id      = openstack_networking_network_v2.this.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers

  allocation_pool {
    start = var.allocation_pool_start
    end   = var.allocation_pool_end
  }
}

# Router connecting private network to external
resource "openstack_networking_router_v2" "this" {
  name                = "${var.prefix}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "this" {
  router_id = openstack_networking_router_v2.this.id
  subnet_id = openstack_networking_subnet_v2.this.id
}

data "openstack_networking_network_v2" "external" {
  name     = var.external_network_name
  external = true
}

# Security groups
resource "openstack_networking_secgroup_v2" "base" {
  name        = "${var.prefix}-base-sg"
  description = "Base security group — deny all inbound except SSH from bastion"
}

resource "openstack_networking_secgroup_rule_v2" "egress_all" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.base.id
}

resource "openstack_networking_secgroup_rule_v2" "ssh_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.bastion_cidr
  security_group_id = openstack_networking_secgroup_v2.base.id
}

resource "openstack_networking_secgroup_v2" "web" {
  name        = "${var.prefix}-web-sg"
  description = "Allow HTTP/HTTPS inbound"
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.web.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.web.id
}
