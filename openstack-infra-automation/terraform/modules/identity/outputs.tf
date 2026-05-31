output "project_id" { value = openstack_identity_project_v3.this.id }
output "user_ids"   { value = { for k, v in openstack_identity_user_v3.service_accounts : k => v.id } }
