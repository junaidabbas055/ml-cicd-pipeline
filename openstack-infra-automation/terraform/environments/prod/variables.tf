variable "key_pair"                 { type = string }
variable "bastion_cidr"             { type = string }
variable "cicd_bot_password"        { type = string; sensitive = true }
variable "monitoring_bot_password"  { type = string; sensitive = true }
