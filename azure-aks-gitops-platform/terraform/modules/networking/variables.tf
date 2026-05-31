variable "prefix" {
  description = "Naming prefix for all resources"
  type        = string
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "resource_group_name" {
  type = string
}

variable "vnet_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "bastion_subnet_cidr" {
  type    = string
  default = "10.10.2.0/27"
}

variable "tags" {
  type    = map(string)
  default = {}
}
