variable "location" {
  type    = string
  default = "centralus"
}

variable "name_prefix" {
  type    = string
  default = "lab"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*[A-Za-z0-9]$", var.name_prefix))
    error_message = "name_prefix must start and end with an alphanumeric and contain only letters, numbers, dot, underscore, or hyphen."
  }
}

variable "hub_resource_group_name" {
  type    = string
  default = "rg-lab-hub-network"
}

variable "spoke1_resource_group_name" {
  type    = string
  default = "rg-lab-spoke1-network"
}

variable "management_resource_group_name" {
  type    = string
  default = "rg-lab-management"
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy into"
}

variable "hub_vnet_cidr" { type = string }
variable "hub_firewall_subnet_cidr" { type = string }
variable "hub_gateway_subnet_cidr" { type = string }
variable "hub_management_subnet_cidr" { type = string }
variable "hub_dns_inbound_subnet_cidr" { type = string }
variable "hub_dns_outbound_subnet_cidr" { type = string }

variable "spoke1_vnet_cidr" { type = string }
variable "spoke1_apps_subnet_cidr" { type = string }
variable "spoke1_apis_subnet_cidr" { type = string }
variable "spoke1_data_subnet_cidr" { type = string }

variable "onprem_public_ip" { type = string }

variable "onprem_address_spaces" {
  type = list(string)
}

variable "vpn_shared_key" {
  type      = string
  sensitive = true
}

variable "vpn_gateway_sku" {
  type    = string
  default = "VpnGw1"
}

variable "tenant_id" { type = string }
variable "acr_name" { type = string }
variable "key_vault_name" { type = string }

variable "onprem_dns_servers" {
  type    = list(string)
  default = ["192.168.1.1"]
}

variable "forward_domain_name" {
  type    = string
  default = "home.arpa."
}

# Jumpbox toggle (default false so deployments proceed without it)
variable "enable_jumpbox" {
  type    = bool
  default = false
}

# Jumpbox static IP so firewall DNAT is plan-safe if enabled
variable "jumpbox_private_ip" {
  type        = string
  description = "Static private IP for jumpbox within hub management subnet (must be inside hub_management_subnet_cidr)"
  default     = "10.10.3.10"
}

# Default to a commonly-available SKU in centralus (but Azure capacity can still vary)
variable "jumpbox_vm_size" {
  type    = string
  default = "Standard_DS1_v2"
}

variable "jumpbox_admin_username" {
  type    = string
  default = "azureuser"
}

variable "jumpbox_ssh_public_key" {
  type        = string
  description = "OpenSSH public key line (ssh-ed25519 ... or ssh-rsa ...)"
  default     = ""
}

variable "enable_jumpbox_dnat" {
  type    = bool
  default = true
}

variable "jumpbox_inbound_port" {
  type    = number
  default = 2222
}

variable "jumpbox_allowed_ssh_source" {
  type        = list(string)
  description = "CIDRs allowed to SSH via firewall DNAT (recommend your public IP /32)"
  default     = ["0.0.0.0/0"]
}
