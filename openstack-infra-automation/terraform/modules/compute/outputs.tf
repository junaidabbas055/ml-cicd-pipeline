output "instance_ids" {
  value = openstack_compute_instance_v2.this[*].id
}

output "instance_ips" {
  value = openstack_compute_instance_v2.this[*].access_ip_v4
}

output "floating_ips" {
  value = var.assign_floating_ip ? openstack_networking_floatingip_v2.this[*].address : []
}
