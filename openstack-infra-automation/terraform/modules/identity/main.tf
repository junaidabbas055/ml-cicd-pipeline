terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

# Keystone project + users + roles
resource "openstack_identity_project_v3" "this" {
  name        = var.project_name
  description = "Project for ${var.environment} environment — managed by Terraform"
  enabled     = true
}

resource "openstack_identity_user_v3" "service_accounts" {
  for_each = var.service_accounts

  name               = each.key
  default_project_id = openstack_identity_project_v3.this.id
  enabled            = true

  password = each.value.password

  extra = {
    email = each.value.email
  }
}

resource "openstack_identity_role_v3" "custom_roles" {
  for_each = toset(var.custom_roles)
  name     = each.value
}

resource "openstack_identity_role_assignment_v3" "assignments" {
  for_each = { for a in var.role_assignments : "${a.user}-${a.role}" => a }

  user_id    = openstack_identity_user_v3.service_accounts[each.value.user].id
  project_id = openstack_identity_project_v3.this.id
  role_id    = openstack_identity_role_v3.custom_roles[each.value.role].id
}
