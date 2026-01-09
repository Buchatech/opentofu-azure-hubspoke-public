variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }

variable "hub_vnet_id" { type = string }
variable "dns_inbound_subnet_id" { type = string }
variable "dns_outbound_subnet_id" { type = string }

variable "onprem_dns_servers" { type = list(string) }
variable "forward_domain_name" { type = string }

variable "link_vnets" {
  type        = map(string)
  description = "Map of friendly name => vnet_id"
}
