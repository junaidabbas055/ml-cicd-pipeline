variable "name"           { type = string }
variable "environment"    { type = string }
variable "role"           { type = string; default = "workload" }
variable "instance_count" { type = number; default = 1 }
variable "image_name"     { type = string; default = "Ubuntu-22.04" }
variable "flavor_name"    { type = string; default = "m1.medium" }
variable "key_pair"       { type = string }
variable "network_name"   { type = string }
variable "security_groups" {
  type    = list(string)
  default = ["default"]
}
variable "assign_floating_ip" { type = bool; default = false }
variable "floating_ip_pool"   { type = string; default = "public" }
variable "data_volume_size"   { type = number; default = 0 }
variable "volume_type"        { type = string; default = "ceph-ssd" }
variable "user_data"          { type = string; default = "" }
