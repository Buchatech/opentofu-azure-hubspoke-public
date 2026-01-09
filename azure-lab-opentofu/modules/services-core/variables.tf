variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }

variable "spoke_private_endpoints_subnet_id" { type = string }

variable "link_vnets" {
  type        = map(string)
  description = "Map of friendly name => vnet_id"
}

variable "acr_name" { type = string }
variable "key_vault_name" { type = string }
