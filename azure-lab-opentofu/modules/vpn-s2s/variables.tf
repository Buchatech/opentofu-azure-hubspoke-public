variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "gateway_subnet_id" { type = string }

variable "onprem_public_ip" { type = string }
variable "onprem_address_spaces" { type = list(string) }

variable "vpn_shared_key" {
  type      = string
  sensitive = true
}

variable "vpn_gateway_sku" { type = string }
