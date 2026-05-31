variable "project_name" { type = string }
variable "environment"  { type = string }

variable "service_accounts" {
  description = "Map of service account name to password and email"
  type = map(object({
    password = string
    email    = string
  }))
  default = {}
}

variable "custom_roles" {
  type    = list(string)
  default = []
}

variable "role_assignments" {
  type = list(object({
    user = string
    role = string
  }))
  default = []
}
