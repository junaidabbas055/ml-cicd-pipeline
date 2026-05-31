variable "prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "aks_cluster_id" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Email address for critical alerts"
}
