variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "system_node_count" {
  description = "Initial system node count"
  type        = number
  default     = 3
}

variable "system_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "system_min_count" {
  description = "Minimum system nodes"
  type        = number
  default     = 2
}

variable "system_max_count" {
  description = "Maximum system nodes"
  type        = number
  default     = 5
}

variable "workload_vm_size" {
  description = "VM size for workload node pool"
  type        = string
  default     = "Standard_D8s_v3"
}

variable "workload_min_count" {
  description = "Minimum workload nodes"
  type        = number
  default     = 2
}

variable "workload_max_count" {
  description = "Maximum workload nodes"
  type        = number
  default     = 20
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for OMS agent"
  type        = string
}

variable "aad_admin_group_ids" {
  description = "AAD group object IDs for cluster admin access"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment label (dev/staging/prod)"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
