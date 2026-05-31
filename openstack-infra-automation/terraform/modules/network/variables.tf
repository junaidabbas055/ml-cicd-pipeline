variable "prefix"                { type = string }
variable "subnet_cidr"           { type = string; default = "192.168.10.0/24" }
variable "allocation_pool_start" { type = string; default = "192.168.10.10" }
variable "allocation_pool_end"   { type = string; default = "192.168.10.200" }
variable "dns_nameservers"       { type = list(string); default = ["8.8.8.8", "8.8.4.4"] }
variable "external_network_name" { type = string; default = "public" }
variable "bastion_cidr"          { type = string; default = "10.0.0.0/8" }
