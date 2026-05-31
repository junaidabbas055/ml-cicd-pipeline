variable "key_pair"           { type = string }
variable "bastion_cidr"       { type = string; default = "10.0.0.0/8" }
variable "cicd_bot_password"  {
  type      = string
  sensitive = true
}
