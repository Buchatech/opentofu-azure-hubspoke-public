variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }

variable "hub_vnet_cidr" { type = string }
variable "hub_firewall_subnet_cidr" { type = string }
variable "hub_gateway_subnet_cidr" { type = string }
variable "hub_management_subnet_cidr" { type = string }
variable "hub_dns_inbound_subnet_cidr" { type = string }
variable "hub_dns_outbound_subnet_cidr" { type = string }
