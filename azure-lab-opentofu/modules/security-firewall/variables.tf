variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "firewall_subnet_id" { type = string }

variable "enable_jumpbox_dnat" {
  type    = bool
  default = true
}

variable "jumpbox_private_ip" { type = string }

variable "jumpbox_inbound_port" {
  type    = number
  default = 2222
}

variable "jumpbox_allowed_sources" {
  type        = list(string)
  description = "Source CIDRs allowed to SSH via DNAT (recommend your public IP /32)"
  default     = ["0.0.0.0/0"]
}
