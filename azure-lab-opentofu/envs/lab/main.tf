terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote state backend - Azure Storage
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "tfstate93306"
    container_name       = "tfstate"
    key                  = "lab.tfstate"
    use_oidc             = true # For GitHub Actions OIDC authentication
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# Resource groups
resource "azurerm_resource_group" "rg_hub" {
  name     = var.hub_resource_group_name
  location = var.location
}

resource "azurerm_resource_group" "rg_spoke1" {
  name     = var.spoke1_resource_group_name
  location = var.location
}

resource "azurerm_resource_group" "rg_mgmt" {
  name     = var.management_resource_group_name
  location = var.location
}

module "hub" {
  source = "../../modules/network-hub"

  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_hub.name

  hub_vnet_cidr                = var.hub_vnet_cidr
  hub_firewall_subnet_cidr     = var.hub_firewall_subnet_cidr
  hub_gateway_subnet_cidr      = var.hub_gateway_subnet_cidr
  hub_management_subnet_cidr   = var.hub_management_subnet_cidr
  hub_dns_inbound_subnet_cidr  = var.hub_dns_inbound_subnet_cidr
  hub_dns_outbound_subnet_cidr = var.hub_dns_outbound_subnet_cidr
}

module "spoke1" {
  source = "../../modules/network-spoke"

  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_spoke1.name

  vnet_cidr        = var.spoke1_vnet_cidr
  apps_subnet_cidr = var.spoke1_apps_subnet_cidr
  apis_subnet_cidr = var.spoke1_apis_subnet_cidr
  data_subnet_cidr = var.spoke1_data_subnet_cidr
}

# Jumpbox (optional). No public IP; static private IP so firewall DNAT is plan-safe.
module "jumpbox" {
  source = "../../modules/compute-jumpbox"

  enabled             = var.enable_jumpbox
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_mgmt.name

  subnet_id  = module.hub.management_subnet_id
  private_ip = var.jumpbox_private_ip

  vm_size        = var.jumpbox_vm_size
  admin_username = var.jumpbox_admin_username
  ssh_public_key = var.jumpbox_ssh_public_key
}

module "firewall" {
  source = "../../modules/security-firewall"

  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_hub.name
  firewall_subnet_id  = module.hub.firewall_subnet_id

  # DNAT only if jumpbox enabled
  enable_jumpbox_dnat     = var.enable_jumpbox && var.enable_jumpbox_dnat
  jumpbox_private_ip      = var.jumpbox_private_ip
  jumpbox_inbound_port    = var.jumpbox_inbound_port
  jumpbox_allowed_sources = var.jumpbox_allowed_ssh_source
}

# Hub management subnet outbound routing via firewall
module "hub_routing" {
  source = "../../modules/hub-routing"

  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_hub.name

  management_subnet_id = module.hub.management_subnet_id
  firewall_private_ip  = module.firewall.firewall_private_ip
}

# S2S VPN (hub)
module "vpn" {
  source = "../../modules/vpn-s2s"

  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_hub.name
  gateway_subnet_id   = module.hub.gateway_subnet_id

  onprem_public_ip      = var.onprem_public_ip
  onprem_address_spaces = var.onprem_address_spaces
  vpn_shared_key        = var.vpn_shared_key
  vpn_gateway_sku       = var.vpn_gateway_sku
}

# Peering + spoke route table (default -> firewall)
module "peering_routing" {
  source = "../../modules/peering-routing"

  name_prefix               = var.name_prefix
  location                  = var.location
  hub_resource_group_name   = azurerm_resource_group.rg_hub.name
  spoke_resource_group_name = azurerm_resource_group.rg_spoke1.name

  hub_vnet_name   = module.hub.vnet_name
  hub_vnet_id     = module.hub.vnet_id
  spoke_vnet_name = module.spoke1.vnet_name
  spoke_vnet_id   = module.spoke1.vnet_id

  spoke_subnets = {
    apps = module.spoke1.apps_subnet_id
    apis = module.spoke1.apis_subnet_id
    data = module.spoke1.data_subnet_id
  }

  firewall_private_ip = module.firewall.firewall_private_ip
}

# Private DNS Resolver + forwarding
module "dns_resolver" {
  source = "../../modules/dns-private-resolver"

  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_hub.name

  hub_vnet_id            = module.hub.vnet_id
  dns_inbound_subnet_id  = module.hub.dns_inbound_subnet_id
  dns_outbound_subnet_id = module.hub.dns_outbound_subnet_id

  onprem_dns_servers  = var.onprem_dns_servers
  forward_domain_name = var.forward_domain_name

  # Map with static keys => plan-safe
  link_vnets = {
    hub    = module.hub.vnet_id
    spoke1 = module.spoke1.vnet_id
  }

  # Wait for VNet modifications to complete before creating DNS resolver
  depends_on = [
    module.firewall,
    module.vpn,
    module.peering_routing
  ]
}

# KV + ACR in management RG + PE in spoke data subnet + private DNS links
module "services" {
  source = "../../modules/services-core"

  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_mgmt.name
  tenant_id           = var.tenant_id

  spoke_private_endpoints_subnet_id = module.spoke1.data_subnet_id

  # Map with static keys => plan-safe
  link_vnets = {
    hub    = module.hub.vnet_id
    spoke1 = module.spoke1.vnet_id
  }

  acr_name       = var.acr_name
  key_vault_name = var.key_vault_name

  # Wait for network configuration to complete before creating private endpoints
  depends_on = [
    module.peering_routing
  ]
}
