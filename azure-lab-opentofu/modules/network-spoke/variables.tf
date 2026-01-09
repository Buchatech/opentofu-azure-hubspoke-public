variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }

variable "vnet_cidr" { type = string }
variable "apps_subnet_cidr" { type = string }
variable "apis_subnet_cidr" { type = string }
variable "data_subnet_cidr" { type = string }
