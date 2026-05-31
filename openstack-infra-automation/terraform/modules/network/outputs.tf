output "network_id"      { value = openstack_networking_network_v2.this.id }
output "network_name"    { value = openstack_networking_network_v2.this.name }
output "subnet_id"       { value = openstack_networking_subnet_v2.this.id }
output "router_id"       { value = openstack_networking_router_v2.this.id }
output "base_sg_id"      { value = openstack_networking_secgroup_v2.base.id }
output "web_sg_id"       { value = openstack_networking_secgroup_v2.web.id }
