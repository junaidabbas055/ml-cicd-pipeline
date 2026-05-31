variable "location" {
  type    = string
  default = "westeurope"
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "vnet_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "bastion_subnet_cidr" {
  type    = string
  default = "10.20.2.0/27"
}

variable "alert_email" {
  type = string
}

variable "aad_admin_group_ids" {
  type    = list(string)
  default = []
}
