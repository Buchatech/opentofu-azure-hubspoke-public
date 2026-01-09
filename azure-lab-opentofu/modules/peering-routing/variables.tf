variable "name_prefix" { type = string }
variable "location" { type = string }

variable "hub_resource_group_name" { type = string }
variable "spoke_resource_group_name" { type = string }

variable "hub_vnet_name" { type = string }
variable "hub_vnet_id" { type = string }
variable "spoke_vnet_name" { type = string }
variable "spoke_vnet_id" { type = string }

variable "spoke_subnets" {
  type        = map(string)
  description = "Map of subnet role => subnet_id"
}

variable "firewall_private_ip" { type = string }
