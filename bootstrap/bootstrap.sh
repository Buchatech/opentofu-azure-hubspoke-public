### 
###
# This makes the folder layout, starter OpenTofu files, a GitHub Actions workflow, and a .gitignore. It does not create the GitHub repo, it just prepares the code and commits locally.

# To run all of this code:
# bash ./create-repo.sh azure-lab-opentofu

# cd azure-lab-opentofu/envs/lab

### Start Bash Script

#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh
# Generates an OpenTofu repo for an Azure hub/spoke lab with two deployment options:
#
# FULL MODE:
# - Private endpoints for Key Vault and ACR
# - Azure DNS Private Resolver with forwarding to on-premises
# - Site-to-Site VPN Gateway with connection to on-premises
# - Optional Jumpbox with DNAT rule through firewall
# - Complete hub-spoke with all security features
#
# BASIC MODE:
# - Public access for Key Vault and ACR (no private endpoints)
# - No DNS Private Resolver
# - No VPN Gateway
# - No Jumpbox
# - Simplified hub-spoke for testing/development
#
# Both modes include:
# - Hub and Spoke VNets with peering
# - Azure Firewall with routing
# - GitHub Actions workflow (plan on PR, apply on main) with OIDC
# - Azure Storage Backend for remote state

########################################
# STEP 0: Select Deployment Type
########################################

echo "================================================"
echo "🚀 OpenTofu Bootstrap - Azure Hub-Spoke"
echo "================================================"
echo ""
echo "Select deployment configuration:"
echo ""
echo "  1) FULL    - Private endpoints, DNS Resolver, S2S VPN, Jumpbox"
echo "  2) BASIC   - Public access, no DNS/VPN/Jumpbox (simplified)"
echo ""
read -p "Enter selection (1 or 2) [default: 1]: " DEPLOYMENT_CHOICE
DEPLOYMENT_CHOICE=${DEPLOYMENT_CHOICE:-1}

if [ "$DEPLOYMENT_CHOICE" = "1" ]; then
  DEPLOYMENT_TYPE="full"
  INCLUDE_DNS_RESOLVER=true
  INCLUDE_VPN=true
  INCLUDE_JUMPBOX_OPTION=true
  USE_PRIVATE_ENDPOINTS=true
  echo ""
  echo "✅ Selected: FULL deployment"
  echo "   - Private endpoints for Key Vault and ACR"
  echo "   - DNS Private Resolver with on-prem forwarding"
  echo "   - Site-to-Site VPN Gateway"
  echo "   - Jumpbox option available (configurable in terraform.tfvars)"
elif [ "$DEPLOYMENT_CHOICE" = "2" ]; then
  DEPLOYMENT_TYPE="basic"
  INCLUDE_DNS_RESOLVER=false
  INCLUDE_VPN=false
  INCLUDE_JUMPBOX_OPTION=false
  USE_PRIVATE_ENDPOINTS=false
  echo ""
  echo "✅ Selected: BASIC deployment"
  echo "   - Public access for Key Vault and ACR"
  echo "   - No DNS Private Resolver"
  echo "   - No VPN Gateway"
  echo "   - No Jumpbox"
else
  echo "❌ Invalid selection. Please run again and choose 1 or 2."
  exit 1
fi

echo ""

########################################
# STEP 0.5: Prompt for Custom Prefix/Name
########################################

echo "================================================"
echo "📝 Repository and Storage Account Naming"
echo "================================================"
echo ""
echo "Enter a unique prefix/name for this deployment."
echo "This will be used for:"
echo "  - Repository folder name (e.g., myproject-azure-lab-opentofu)"
echo "  - Storage account name (e.g., tfstatemyproject)"
echo ""
echo "Requirements:"
echo "  - Lowercase letters and numbers only"
echo "  - 3-15 characters recommended"
echo "  - Must be unique across Azure (for storage account)"
echo ""
read -p "Enter prefix [default: lab]: " CUSTOM_PREFIX
CUSTOM_PREFIX=${CUSTOM_PREFIX:-lab}

# Validate prefix (lowercase alphanumeric only)
if ! [[ "$CUSTOM_PREFIX" =~ ^[a-z0-9]+$ ]]; then
  echo "❌ Invalid prefix. Use only lowercase letters and numbers."
  exit 1
fi

# Ensure prefix is not too long (storage account has 24 char limit, tfstate prefix uses 7)
if [ ${#CUSTOM_PREFIX} -gt 15 ]; then
  echo "❌ Prefix too long. Maximum 15 characters."
  exit 1
fi

echo ""
echo "✅ Using prefix: $CUSTOM_PREFIX"
echo ""

########################################
# STEP 1: Create Azure Storage for State
########################################

echo "================================================"
echo "🚀 OpenTofu Bootstrap - Creating State Storage"
echo "================================================"
echo ""

# Configuration for state storage with custom prefix
TFSTATE_RG="${TFSTATE_RG_NAME:-rg-tfstate-${CUSTOM_PREFIX}}"
TFSTATE_SA="${TFSTATE_SA_NAME:-tfstate${CUSTOM_PREFIX}$(date +%s | tail -c 6)}"
TFSTATE_CONTAINER="${TFSTATE_CONTAINER:-tfstate}"
TFSTATE_LOCATION="${TFSTATE_LOCATION:-centralus}"

echo "📋 State Storage Configuration:"
echo "   Resource Group:    $TFSTATE_RG"
echo "   Storage Account:   $TFSTATE_SA"
echo "   Container:         $TFSTATE_CONTAINER"
echo "   Location:          $TFSTATE_LOCATION"
echo ""

# Check if logged into Azure
if ! az account show &>/dev/null; then
  echo "❌ Not logged into Azure. Please run: az login"
  exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "✅ Using subscription: $SUBSCRIPTION_NAME"
echo "   Subscription ID:    $SUBSCRIPTION_ID"
echo ""

# Create resource group for state
echo "📦 Creating state resource group..."
az group create \
  --name "$TFSTATE_RG" \
  --location "$TFSTATE_LOCATION" \
  --output none

echo "✅ Resource group created"

# Create storage account for state
echo "💾 Creating state storage account..."
az storage account create \
  --name "$TFSTATE_SA" \
  --resource-group "$TFSTATE_RG" \
  --location "$TFSTATE_LOCATION" \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

echo "✅ Storage account created"

# Create blob container for state
echo "📂 Creating state container..."
az storage container create \
  --name "$TFSTATE_CONTAINER" \
  --account-name "$TFSTATE_SA" \
  --auth-mode login \
  --output none

echo "✅ Container created"
echo ""
echo "================================================"
echo "✅ State Storage Ready!"
echo "================================================"
echo ""

########################################
# STEP 2: Create OpenTofu Repository
########################################

echo "================================================"
echo "📦 Creating OpenTofu Repository Structure"
echo "================================================"
echo ""

# Use custom prefix for repository name
REPO_NAME="${CUSTOM_PREFIX}-azure-lab-opentofu"

echo "📁 Repository name: $REPO_NAME"
echo ""

# Create repository in parent directory (root of solution)
mkdir -p "../$REPO_NAME"
cd "../$REPO_NAME"

git init >/dev/null 2>&1 || true

# Copy bootstrap folder and README into the new repository
echo "📋 Copying bootstrap folder and README into repository..."
cp -r ../azure-lab-opentf/bootstrap ./
cp ../azure-lab-opentf/README.md ./
echo "✅ Bootstrap folder and README copied"
echo ""

# Create module directories based on deployment type
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  mkdir -p \
    modules/{network-hub,network-spoke,security-firewall,hub-routing,vpn-s2s,peering-routing,dns-private-resolver,services-core} \
    envs/lab \
    .github/workflows
  echo "📁 Creating full module structure (including DNS resolver and VPN)"
else
  mkdir -p \
    modules/{network-hub,network-spoke,security-firewall,hub-routing,peering-routing,services-core} \
    envs/lab \
    .github/workflows
  echo "📁 Creating basic module structure (no DNS resolver or VPN)"
fi

########################################
# .gitignore
########################################
cat > .gitignore <<'GITIGNORE_EOF'
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.*
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.env
.DS_Store
GITIGNORE_EOF

########################################
# envs/lab/main.tf
########################################
# Generate main.tf based on deployment type
cat > envs/lab/main.tf <<ROOT_MAIN_EOF
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
    resource_group_name  = "$TFSTATE_RG"
    storage_account_name = "$TFSTATE_SA"
    container_name       = "$TFSTATE_CONTAINER"
    key                  = "lab.tfstate"
    use_oidc             = true  # For GitHub Actions OIDC authentication
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

  name_prefix                  = var.name_prefix
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg_hub.name

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

ROOT_MAIN_EOF

# Add jumpbox module only for FULL mode
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/main.tf <<'ROOT_MAIN_JUMPBOX'
# Jumpbox (optional). No public IP; static private IP so firewall DNAT is plan-safe.
module "jumpbox" {
  source = "../../modules/compute-jumpbox"

  enabled             = var.enable_jumpbox
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_mgmt.name

  subnet_id      = module.hub.management_subnet_id
  private_ip     = var.jumpbox_private_ip

  vm_size        = var.jumpbox_vm_size
  admin_username = var.jumpbox_admin_username
  ssh_public_key = var.jumpbox_ssh_public_key
}

ROOT_MAIN_JUMPBOX
fi

# Continue with common modules
cat >> envs/lab/main.tf <<'ROOT_MAIN_FIREWALL'
module "firewall" {
  source = "../../modules/security-firewall"

  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_hub.name
  firewall_subnet_id  = module.hub.firewall_subnet_id
ROOT_MAIN_FIREWALL

# Add DNAT configuration only for FULL mode
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/main.tf <<'ROOT_MAIN_FIREWALL_DNAT'

  # DNAT only if jumpbox enabled
  enable_jumpbox_dnat     = var.enable_jumpbox && var.enable_jumpbox_dnat
  jumpbox_private_ip      = var.jumpbox_private_ip
  jumpbox_inbound_port    = var.jumpbox_inbound_port
  jumpbox_allowed_sources = var.jumpbox_allowed_ssh_source
ROOT_MAIN_FIREWALL_DNAT
fi

# Close firewall module
cat >> envs/lab/main.tf <<'ROOT_MAIN_FIREWALL_END'
}

# Hub management subnet outbound routing via firewall
module "hub_routing" {
  source = "../../modules/hub-routing"

  name_prefix          = var.name_prefix
  location             = var.location
  resource_group_name  = azurerm_resource_group.rg_hub.name

  management_subnet_id = module.hub.management_subnet_id
  firewall_private_ip  = module.firewall.firewall_private_ip
}

ROOT_MAIN_FIREWALL_END

# Add VPN module only for FULL mode
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/main.tf <<'ROOT_MAIN_VPN'
# S2S VPN (hub)
module "vpn" {
  source = "../../modules/vpn-s2s"

  name_prefix           = var.name_prefix
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg_hub.name
  gateway_subnet_id     = module.hub.gateway_subnet_id

  onprem_public_ip      = var.onprem_public_ip
  onprem_address_spaces = var.onprem_address_spaces
  vpn_shared_key        = var.vpn_shared_key
  vpn_gateway_sku       = var.vpn_gateway_sku
}

ROOT_MAIN_VPN
fi

# Add peering module
cat >> envs/lab/main.tf <<'ROOT_MAIN_PEERING'
# Peering + spoke route table (default -> firewall)
module "peering_routing" {
  source = "../../modules/peering-routing"

  name_prefix                = var.name_prefix
  location                   = var.location
  hub_resource_group_name    = azurerm_resource_group.rg_hub.name
  spoke_resource_group_name  = azurerm_resource_group.rg_spoke1.name

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

ROOT_MAIN_PEERING

# Add DNS resolver only for FULL mode
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/main.tf <<'ROOT_MAIN_DNS'
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

ROOT_MAIN_DNS
fi

# Add services module - different configuration for FULL vs BASIC
cat >> envs/lab/main.tf <<'ROOT_MAIN_SERVICES_START'
# KV + ACR in management RG
module "services" {
  source = "../../modules/services-core"

  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_mgmt.name
  tenant_id           = var.tenant_id
ROOT_MAIN_SERVICES_START

if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  # FULL mode: Add private endpoints configuration
  cat >> envs/lab/main.tf <<'ROOT_MAIN_SERVICES_FULL'

  spoke_private_endpoints_subnet_id = module.spoke1.data_subnet_id

  # Map with static keys => plan-safe
  link_vnets = {
    hub    = module.hub.vnet_id
    spoke1 = module.spoke1.vnet_id
  }
ROOT_MAIN_SERVICES_FULL
fi

# Add common service configuration
cat >> envs/lab/main.tf <<'ROOT_MAIN_SERVICES_END'

  acr_name       = var.acr_name
  key_vault_name = var.key_vault_name

  # Wait for network configuration to complete before creating private endpoints
  depends_on = [
    module.peering_routing
  ]
}
ROOT_MAIN_SERVICES_END

########################################
# envs/lab/variables.tf (multi-line safe)
########################################
# Common variables for both deployment types
cat > envs/lab/variables.tf <<'ROOT_VARS_COMMON'
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

ROOT_VARS_COMMON

# Add VPN variables for FULL mode only
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/variables.tf <<'ROOT_VARS_VPN'
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

ROOT_VARS_VPN
fi

# Add common service variables
cat >> envs/lab/variables.tf <<'ROOT_VARS_SERVICES'
variable "tenant_id" { type = string }
variable "acr_name" { type = string }
variable "key_vault_name" { type = string }

ROOT_VARS_SERVICES

# Add DNS and Jumpbox variables for FULL mode only
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/variables.tf <<'ROOT_VARS_DNS_JUMPBOX'
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
ROOT_VARS_DNS_JUMPBOX
fi

########################################
# envs/lab/outputs.tf (ternary-safe formatting)
########################################
# Common outputs for both deployment types
cat > envs/lab/outputs.tf <<'ROOT_OUT_COMMON'
output "hub_resource_group" {
  value = azurerm_resource_group.rg_hub.name
}

output "spoke1_resource_group" {
  value = azurerm_resource_group.rg_spoke1.name
}

output "management_resource_group" {
  value = azurerm_resource_group.rg_mgmt.name
}

output "firewall_public_ip" {
  value = module.firewall.firewall_public_ip
}

output "firewall_private_ip" {
  value = module.firewall.firewall_private_ip
}

ROOT_OUT_COMMON

# Add VPN outputs for FULL mode only
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/outputs.tf <<'ROOT_OUT_VPN'
output "vpn_gateway_public_ip" {
  value = module.vpn.vpn_gateway_public_ip
}

ROOT_OUT_VPN
fi

# Add DNS outputs for FULL mode only
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/outputs.tf <<'ROOT_OUT_DNS'
output "dns_inbound_endpoint_ip" {
  value = module.dns_resolver.inbound_endpoint_ip
}

ROOT_OUT_DNS
fi

# Add common service outputs
cat >> envs/lab/outputs.tf <<'ROOT_OUT_SERVICES'
output "acr_login_server" {
  value = module.services.acr_login_server
}

output "key_vault_uri" {
  value = module.services.key_vault_uri
}

ROOT_OUT_SERVICES

# Add jumpbox outputs for FULL mode only
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/outputs.tf <<'ROOT_OUT_JUMPBOX'
output "jumpbox_private_ip" {
  value = module.jumpbox.private_ip
}

output "jumpbox_ssh_via_firewall" {
  value = (var.enable_jumpbox
    ? "ssh -p ${var.jumpbox_inbound_port} ${var.jumpbox_admin_username}@${module.firewall.firewall_public_ip}"
    : null
  )
}

output "jumpbox_status" {
  value = (var.enable_jumpbox
    ? "Jumpbox enabled. If VM creation fails due to SKU capacity, change jumpbox_vm_size (envs/lab/terraform.tfvars) or set enable_jumpbox=false and re-run apply."
    : "Jumpbox disabled. Core infrastructure deployed without a jumpbox."
  )
}

output "ssh_source_warning" {
  value = (contains(var.jumpbox_allowed_ssh_source, "0.0.0.0/0")
    ? "WARNING: jumpbox_allowed_ssh_source is 0.0.0.0/0. Lock it down to your public IP /32."
    : null
  )
}
ROOT_OUT_JUMPBOX
fi

########################################
# envs/lab/terraform.tfvars
########################################
# Generate terraform.tfvars based on deployment type
cat > envs/lab/terraform.tfvars <<TFVARS_COMMON
location    = "centralus"
name_prefix = "${CUSTOM_PREFIX}"

hub_resource_group_name        = "rg-${CUSTOM_PREFIX}-hub-network"
spoke1_resource_group_name     = "rg-${CUSTOM_PREFIX}-spoke1-network"
management_resource_group_name = "rg-${CUSTOM_PREFIX}-management"

subscription_id = "YOUR_SUBSCRIPTION_GUID"

hub_vnet_cidr                = "10.10.0.0/16"
hub_firewall_subnet_cidr     = "10.10.1.0/26"
hub_gateway_subnet_cidr      = "10.10.2.0/27"
hub_management_subnet_cidr   = "10.10.3.0/24"
hub_dns_inbound_subnet_cidr  = "10.10.4.0/28"
hub_dns_outbound_subnet_cidr = "10.10.5.0/28"

spoke1_vnet_cidr        = "10.20.0.0/16"
spoke1_apps_subnet_cidr = "10.20.1.0/24"
spoke1_apis_subnet_cidr = "10.20.2.0/24"
spoke1_data_subnet_cidr = "10.20.3.0/24"

TFVARS_COMMON

if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/terraform.tfvars <<'TFVARS_FULL'
# VPN Configuration (for Site-to-Site VPN)
onprem_public_ip      = "X.X.X.X"
onprem_address_spaces = ["192.168.1.0/24"]
vpn_shared_key        = "REPLACE_ME"
vpn_gateway_sku       = "VpnGw1"

TFVARS_FULL
fi

cat >> envs/lab/terraform.tfvars <<'TFVARS_COMMON2'
tenant_id = "YOUR_TENANT_GUID"

# MUST be globally unique + lowercase
acr_name       = "acrlabsteve12345"
key_vault_name = "kvlabsteve12345"

TFVARS_COMMON2

if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> envs/lab/terraform.tfvars <<'TFVARS_DNS_JUMPBOX'
# DNS Configuration (for DNS Private Resolver)
onprem_dns_servers  = ["192.168.1.1"]
forward_domain_name = "home.arpa."

# Jumpbox (optional)
enable_jumpbox         = false
jumpbox_private_ip     = "10.10.3.10"
jumpbox_vm_size        = "Standard_DS1_v2"
jumpbox_admin_username = "azureuser"
jumpbox_ssh_public_key = ""

# Firewall DNAT -> jumpbox (only applies if enable_jumpbox=true)
enable_jumpbox_dnat        = true
jumpbox_inbound_port       = 2222
jumpbox_allowed_ssh_source = ["0.0.0.0/0"]
TFVARS_DNS_JUMPBOX
else
  cat >> envs/lab/terraform.tfvars <<'TFVARS_BASIC'
# BASIC mode: No VPN, DNS Resolver, or Jumpbox
# Key Vault and ACR will use public access
TFVARS_BASIC
fi

########################################
# modules/network-hub
########################################
cat > modules/network-hub/variables.tf <<'HUB_VARS_EOF'
variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }

variable "hub_vnet_cidr" { type = string }
variable "hub_firewall_subnet_cidr" { type = string }
variable "hub_gateway_subnet_cidr" { type = string }
variable "hub_management_subnet_cidr" { type = string }
variable "hub_dns_inbound_subnet_cidr" { type = string }
variable "hub_dns_outbound_subnet_cidr" { type = string }
HUB_VARS_EOF

cat > modules/network-hub/main.tf <<'HUB_MAIN_EOF'
resource "azurerm_virtual_network" "hub" {
  name                = "${var.name_prefix}-vnet-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.hub_vnet_cidr]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_firewall_subnet_cidr]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_gateway_subnet_cidr]
}

resource "azurerm_subnet" "management" {
  name                 = "Management"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_management_subnet_cidr]
}

resource "azurerm_subnet" "dns_inbound" {
  name                 = "DnsInbound"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_dns_inbound_subnet_cidr]

  delegation {
    name = "dns-inbound"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "dns_outbound" {
  name                 = "DnsOutbound"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_dns_outbound_subnet_cidr]

  delegation {
    name = "dns-outbound"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
HUB_MAIN_EOF

cat > modules/network-hub/outputs.tf <<'HUB_OUT_EOF'
output "vnet_id" { value = azurerm_virtual_network.hub.id }
output "vnet_name" { value = azurerm_virtual_network.hub.name }

output "firewall_subnet_id" { value = azurerm_subnet.firewall.id }
output "gateway_subnet_id" { value = azurerm_subnet.gateway.id }
output "management_subnet_id" { value = azurerm_subnet.management.id }
output "dns_inbound_subnet_id" { value = azurerm_subnet.dns_inbound.id }
output "dns_outbound_subnet_id" { value = azurerm_subnet.dns_outbound.id }
HUB_OUT_EOF

########################################
# modules/network-spoke
########################################
cat > modules/network-spoke/variables.tf <<'SPOKE_VARS_EOF'
variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }

variable "vnet_cidr" { type = string }
variable "apps_subnet_cidr" { type = string }
variable "apis_subnet_cidr" { type = string }
variable "data_subnet_cidr" { type = string }
SPOKE_VARS_EOF

cat > modules/network-spoke/main.tf <<'SPOKE_MAIN_EOF'
resource "azurerm_virtual_network" "spoke" {
  name                = "${var.name_prefix}-vnet-spoke1"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "apps" {
  name                 = "Apps"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.apps_subnet_cidr]

  # Required for Private Endpoints
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "apis" {
  name                 = "APIs"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.apis_subnet_cidr]

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "data" {
  name                 = "Data"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.data_subnet_cidr]

  private_endpoint_network_policies = "Disabled"
}
SPOKE_MAIN_EOF

cat > modules/network-spoke/outputs.tf <<'SPOKE_OUT_EOF'
output "vnet_id" { value = azurerm_virtual_network.spoke.id }
output "vnet_name" { value = azurerm_virtual_network.spoke.name }

output "apps_subnet_id" { value = azurerm_subnet.apps.id }
output "apis_subnet_id" { value = azurerm_subnet.apis.id }
output "data_subnet_id" { value = azurerm_subnet.data.id }
SPOKE_OUT_EOF

########################################
# modules/compute-jumpbox (FULL mode only)
########################################
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat > modules/compute-jumpbox/variables.tf <<'JB_VARS_EOF'
variable "enabled" {
  type    = bool
  default = true
}

variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }

variable "subnet_id" { type = string }

variable "private_ip" {
  type        = string
  description = "Static private IP for the NIC"
}

variable "vm_size" { type = string }
variable "admin_username" { type = string }

variable "ssh_public_key" {
  type        = string
  description = "OpenSSH public key line (ssh-ed25519 ... or ssh-rsa ...)"
}
JB_VARS_EOF

  cat > modules/compute-jumpbox/main.tf <<'JB_MAIN_EOF'
resource "azurerm_network_interface" "nic" {
  count               = var.enabled ? 1 : 0
  name                = "${var.name_prefix}-nic-jumpbox"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.private_ip
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.enabled ? 1 : 0
  name                = "${var.name_prefix}-vm-jumpbox"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.nic[0].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }
}
JB_MAIN_EOF

  cat > modules/compute-jumpbox/outputs.tf <<'JB_OUT_EOF'
output "private_ip" {
  value = var.enabled ? var.private_ip : null
}
JB_OUT_EOF
fi

########################################
# modules/security-firewall
########################################
cat > modules/security-firewall/variables.tf <<'FW_VARS_START'
variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "firewall_subnet_id" { type = string }

FW_VARS_START

# Add DNAT variables only for FULL mode
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> modules/security-firewall/variables.tf <<'FW_VARS_DNAT'
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
FW_VARS_DNAT
fi

cat > modules/security-firewall/main.tf <<'FW_MAIN_START'
resource "azurerm_public_ip" "pip" {
  name                = "${var.name_prefix}-pip-azfw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "fw" {
  name                = "${var.name_prefix}-azfw"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku_name = "AZFW_VNet"
  sku_tier = "Standard"

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

FW_MAIN_START

# Add DNAT rules only for FULL mode
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> modules/security-firewall/main.tf <<'FW_MAIN_DNAT'
resource "azurerm_firewall_nat_rule_collection" "jumpbox_dnat" {
  count               = var.enable_jumpbox_dnat ? 1 : 0
  name                = "${var.name_prefix}-nat-jumpbox"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.resource_group_name
  priority            = 100
  action              = "Dnat"

  rule {
    name                  = "dnat-ssh-jumpbox"
    protocols             = ["TCP"]
    source_addresses      = var.jumpbox_allowed_sources
    destination_addresses = [azurerm_public_ip.pip.ip_address]
    destination_ports     = [tostring(var.jumpbox_inbound_port)]
    translated_address    = var.jumpbox_private_ip
    translated_port       = "22"
  }
}

resource "azurerm_firewall_network_rule_collection" "jumpbox_allow" {
  count               = var.enable_jumpbox_dnat ? 1 : 0
  name                = "${var.name_prefix}-net-jumpbox"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.resource_group_name
  priority            = 110
  action              = "Allow"

  rule {
    name                  = "allow-ssh-to-jumpbox"
    protocols             = ["TCP"]
    source_addresses      = var.jumpbox_allowed_sources
    destination_addresses = [var.jumpbox_private_ip]
    destination_ports     = ["22"]
  }
}
FW_MAIN_DNAT
fi

cat > modules/security-firewall/outputs.tf <<'FW_OUT_EOF'
output "firewall_private_ip" { value = azurerm_firewall.fw.ip_configuration[0].private_ip_address }
output "firewall_public_ip" { value = azurerm_public_ip.pip.ip_address }
output "firewall_name" { value = azurerm_firewall.fw.name }
FW_OUT_EOF

########################################
# modules/hub-routing
########################################
cat > modules/hub-routing/variables.tf <<'HUBRT_VARS_EOF'
variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }

variable "management_subnet_id" { type = string }
variable "firewall_private_ip" { type = string }
HUBRT_VARS_EOF

cat > modules/hub-routing/main.tf <<'HUBRT_MAIN_EOF'
resource "azurerm_route_table" "rt" {
  name                = "${var.name_prefix}-rt-hub-mgmt"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_route" "default_to_fw" {
  name                   = "default-to-azfw"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.rt.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

resource "azurerm_subnet_route_table_association" "assoc" {
  subnet_id      = var.management_subnet_id
  route_table_id = azurerm_route_table.rt.id
}
HUBRT_MAIN_EOF

cat > modules/hub-routing/outputs.tf <<'HUBRT_OUT_EOF'
output "route_table_id" { value = azurerm_route_table.rt.id }
HUBRT_OUT_EOF

########################################
# modules/vpn-s2s (FULL mode only)
########################################
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat > modules/vpn-s2s/variables.tf <<'VPN_VARS_EOF'
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
VPN_VARS_EOF

  cat > modules/vpn-s2s/main.tf <<'VPN_MAIN_EOF'
resource "azurerm_public_ip" "pip" {
  name                = "${var.name_prefix}-pip-vpngw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network_gateway" "gw" {
  name                = "${var.name_prefix}-vpngw"
  location            = var.location
  resource_group_name = var.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = var.vpn_gateway_sku

  active_active = false
  enable_bgp    = false

  ip_configuration {
    name                          = "vpngw-ipconfig"
    public_ip_address_id          = azurerm_public_ip.pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }
}

resource "azurerm_local_network_gateway" "lng" {
  name                = "${var.name_prefix}-lng-home"
  location            = var.location
  resource_group_name = var.resource_group_name

  gateway_address = var.onprem_public_ip
  address_space   = var.onprem_address_spaces
}

resource "azurerm_virtual_network_gateway_connection" "conn" {
  name                = "${var.name_prefix}-conn-home"
  location            = var.location
  resource_group_name = var.resource_group_name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.gw.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng.id
  shared_key                 = var.vpn_shared_key
}
VPN_MAIN_EOF

  cat > modules/vpn-s2s/outputs.tf <<'VPN_OUT_EOF'
output "vpn_gateway_public_ip" { value = azurerm_public_ip.pip.ip_address }
VPN_OUT_EOF
fi

########################################
# modules/peering-routing
########################################
cat > modules/peering-routing/variables.tf <<'PEER_VARS_EOF'
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
PEER_VARS_EOF

cat > modules/peering-routing/main.tf <<'PEER_MAIN_EOF'
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-spoke1"
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = var.spoke_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-spoke1-to-hub"
  resource_group_name       = var.spoke_resource_group_name
  virtual_network_name      = var.spoke_vnet_name
  remote_virtual_network_id = var.hub_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # Keep false unless you explicitly enable gateway transit on hub
  use_remote_gateways = false
}

resource "azurerm_route_table" "rt" {
  name                = "${var.name_prefix}-rt-spoke1"
  location            = var.location
  resource_group_name = var.spoke_resource_group_name
}

resource "azurerm_route" "default" {
  name                   = "default-to-azfw"
  resource_group_name    = var.spoke_resource_group_name
  route_table_name       = azurerm_route_table.rt.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

resource "azurerm_subnet_route_table_association" "assoc" {
  for_each       = var.spoke_subnets
  subnet_id      = each.value
  route_table_id = azurerm_route_table.rt.id
}
PEER_MAIN_EOF

cat > modules/peering-routing/outputs.tf <<'PEER_OUT_EOF'
output "route_table_id" { value = azurerm_route_table.rt.id }
PEER_OUT_EOF

########################################
# modules/dns-private-resolver (FULL mode only)
########################################
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat > modules/dns-private-resolver/variables.tf <<'DNS_VARS_EOF'
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
DNS_VARS_EOF

  cat > modules/dns-private-resolver/main.tf <<'DNS_MAIN_EOF'
resource "azurerm_private_dns_resolver" "resolver" {
  name                = "${var.name_prefix}-dnspr"
  location            = var.location
  resource_group_name = var.resource_group_name
  virtual_network_id  = var.hub_vnet_id
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "inbound" {
  name                    = "${var.name_prefix}-dnspr-in"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.resolver.id

  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = var.dns_inbound_subnet_id
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "outbound" {
  name                    = "${var.name_prefix}-dnspr-out"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.resolver.id
  subnet_id               = var.dns_outbound_subnet_id
}

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "ruleset" {
  name                = "${var.name_prefix}-dnspr-ruleset"
  location            = var.location
  resource_group_name = var.resource_group_name

  private_dns_resolver_outbound_endpoint_ids = [
    azurerm_private_dns_resolver_outbound_endpoint.outbound.id
  ]
}

resource "azurerm_private_dns_resolver_forwarding_rule" "forward" {
  name                      = "forward-onprem"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.ruleset.id
  domain_name               = var.forward_domain_name

  target_dns_servers {
    ip_address = var.onprem_dns_servers[0]
    port       = 53
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "links" {
  for_each = var.link_vnets

  name                      = "link-${each.key}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.ruleset.id
  virtual_network_id        = each.value
}
DNS_MAIN_EOF

  cat > modules/dns-private-resolver/outputs.tf <<'DNS_OUT_EOF'
output "inbound_endpoint_ip" {
  value = azurerm_private_dns_resolver_inbound_endpoint.inbound.ip_configurations[0].private_ip_address
}
DNS_OUT_EOF
fi

########################################
# modules/services-core
########################################
# Base variables (common to both modes)
cat > modules/services-core/variables.tf <<'SVC_VARS_EOF'
variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }

variable "acr_name" { type = string }
variable "key_vault_name" { type = string }
SVC_VARS_EOF

# Add private endpoint variables only for FULL mode
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  cat >> modules/services-core/variables.tf <<'SVC_VARS_PRIVATE_EOF'

variable "spoke_private_endpoints_subnet_id" { type = string }

variable "link_vnets" {
  type        = map(string)
  description = "Map of friendly name => vnet_id"
}
SVC_VARS_PRIVATE_EOF
fi

if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  # FULL mode: Private endpoints with DNS zones
  cat > modules/services-core/main.tf <<'SVC_MAIN_FULL_EOF'
resource "azurerm_private_dns_zone" "kv_zone" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone" "acr_zone" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_links" {
  for_each = var.link_vnets

  name                  = "kv-link-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv_zone.name
  virtual_network_id    = each.value
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_links" {
  for_each = var.link_vnets

  name                  = "acr-link-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr_zone.name
  virtual_network_id    = each.value
}

resource "azurerm_container_registry" "acr" {
  name                          = var.acr_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
}

resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  public_network_access_enabled = false
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
}

resource "azurerm_private_endpoint" "acr_pe" {
  name                = "${var.name_prefix}-pe-acr"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.spoke_private_endpoints_subnet_id

  private_service_connection {
    name                           = "${var.name_prefix}-psc-acr"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr_zone.id]
  }
}

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "${var.name_prefix}-pe-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.spoke_private_endpoints_subnet_id

  private_service_connection {
    name                           = "${var.name_prefix}-psc-kv"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_zone.id]
  }
}
SVC_MAIN_FULL_EOF
else
  # BASIC mode: Public access enabled
  cat > modules/services-core/main.tf <<'SVC_MAIN_BASIC_EOF'
resource "azurerm_container_registry" "acr" {
  name                          = var.acr_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Standard"
  admin_enabled                 = true
  public_network_access_enabled = true
}

resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  public_network_access_enabled = true
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
}
SVC_MAIN_BASIC_EOF
fi

cat > modules/services-core/outputs.tf <<'SVC_OUT_EOF'
output "acr_login_server" { value = azurerm_container_registry.acr.login_server }
output "key_vault_uri" { value = azurerm_key_vault.kv.vault_uri }
SVC_OUT_EOF

########################################
# GitHub Actions workflow
########################################
cat > .github/workflows/tofu.yml <<'GHA_EOF'
name: opentofu

on:
  pull_request:
    paths:
      - "**/*.tf"
      - "**/*.tfvars"
      - ".github/workflows/tofu.yml"
  push:
    branches: ["main"]
    paths:
      - "**/*.tf"
      - "**/*.tfvars"
      - ".github/workflows/tofu.yml"

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: envs/lab
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      ARM_USE_OIDC: true
    steps:
      - uses: actions/checkout@v4
      - uses: opentofu/setup-opentofu@v1
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - name: tofu fmt
        run: tofu fmt -check -recursive
      - name: tofu init
        run: tofu init
      - name: tofu validate
        run: tofu validate
      - name: tofu plan
        run: tofu plan -no-color

  apply:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: envs/lab
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      ARM_USE_OIDC: true
    steps:
      - uses: actions/checkout@v4
      - uses: opentofu/setup-opentofu@v1
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - name: tofu init
        run: tofu init
      - name: tofu apply
        run: tofu apply -auto-approve
      - name: tofu output
        run: tofu output
GHA_EOF

########################################
# Helper (non-fatal): try to populate jumpbox_ssh_public_key from ~/.ssh/id_ed25519.pub
########################################
TFVARS_PATH="envs/lab/terraform.tfvars"
SSH_PUB_PATH="${HOME}/.ssh/id_ed25519.pub"

if [[ -f "$SSH_PUB_PATH" ]]; then
  SSH_PUB_KEY="$(tr -d '\r\n' < "$SSH_PUB_PATH" | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ +| +$//g')"
  if [[ "$SSH_PUB_KEY" =~ ^(ssh-ed25519|ssh-rsa)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$ ]]; then
    if sed --version >/dev/null 2>&1; then
      sed -i "s|^jumpbox_ssh_public_key[[:space:]]*=.*$|jumpbox_ssh_public_key = \"${SSH_PUB_KEY}\"|g" "$TFVARS_PATH"
    else
      sed -i '' "s|^jumpbox_ssh_public_key[[:space:]]*=.*$|jumpbox_ssh_public_key = \"${SSH_PUB_KEY}\"|g" "$TFVARS_PATH"
    fi
    echo "Populated jumpbox_ssh_public_key from ${SSH_PUB_PATH} (jumpbox remains disabled by default)."
  else
    echo "WARNING: ${SSH_PUB_PATH} exists but does not look like a valid OpenSSH public key line."
    echo "WARNING: Leaving jumpbox_ssh_public_key as placeholder in ${TFVARS_PATH}."
  fi
else
  echo "WARNING: ${SSH_PUB_PATH} not found. Leaving jumpbox_ssh_public_key as placeholder in ${TFVARS_PATH}."
fi

########################################
# Initial commit
########################################
git add . >/dev/null 2>&1 || true
if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  git commit -m "Initial hub/spoke lab with VPN, DNS, and optional jumpbox" >/dev/null 2>&1 || true
else
  git commit -m "Initial basic hub/spoke lab with public access" >/dev/null 2>&1 || true
fi

echo
echo "Repo created at: $(pwd)"
echo

if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  echo "========================================="
  echo "FULL DEPLOYMENT MODE"
  echo "========================================="
  echo "Includes: Private Endpoints, DNS Resolver, S2S VPN, Optional Jumpbox"
  echo
  echo "Next steps:"
  echo "1) Edit envs/lab/terraform.tfvars:"
  echo "   - subscription_id, tenant_id"
  echo "   - onprem_public_ip (your on-prem VPN endpoint)"
  echo "   - vpn_shared_key (strong PSK for VPN)"
  echo "   - onprem_dns_servers (on-prem DNS IPs)"
  echo "   - forward_domain_name (e.g. corp.local)"
  echo "   - acr_name, key_vault_name (unique lowercase)"
  echo "   - (optional) enable_jumpbox=true and set jumpbox_ssh_public_key"
  echo "   - (recommended) lock down jumpbox_allowed_ssh_source to your public IP /32"
  echo
else
  echo "========================================="
  echo "BASIC DEPLOYMENT MODE"
  echo "========================================="
  echo "Includes: Hub-Spoke Network, Firewall, Public ACR/KeyVault"
  echo "Excludes: DNS Resolver, VPN Gateway, Jumpbox"
  echo
  echo "Next steps:"
  echo "1) Edit envs/lab/terraform.tfvars:"
  echo "   - subscription_id, tenant_id"
  echo "   - acr_name, key_vault_name (unique lowercase)"
  echo
fi

echo "2) Then run:"
echo "   cd envs/lab"
echo "   tofu fmt -recursive"
echo "   tofu init -upgrade"
echo "   tofu plan"
echo "   tofu apply"
echo

if [ "$DEPLOYMENT_TYPE" = "full" ]; then
  echo "===================================================================="
  echo "IMPORTANT: Azure VM capacity notice"
  echo "--------------------------------------------------------------------"
  echo "Azure often has regional VM SKU capacity constraints (409 SkuNotAvailable)."
  echo
  echo "Jumpbox is OPTIONAL and disabled by default:"
  echo "  enable_jumpbox = false   (envs/lab/terraform.tfvars)"
  echo
  echo "If you enable it and Azure rejects the VM size, change it here:"
  echo "  envs/lab/terraform.tfvars"
  echo "  jumpbox_vm_size = \"<SKU>\""
  echo
  echo "Common SKUs often available in centralus for a jumpbox:"
  echo "  - Standard_DS1_v2   (jumpbox king)"
  echo "  - Standard_D2s_v3"
  echo "  - Standard_F2s_v2"
  echo
  echo "If jumpbox capacity is blocked, proceed without it:"
  echo "  enable_jumpbox = false"
  echo "Then re-run: tofu apply"
  echo "===================================================================="
  echo
fi

echo "===================================================================="
echo "📦 AZURE STORAGE BACKEND CREATED"
echo "===================================================================="
echo
echo "Remote state is configured in envs/lab/main.tf with:"
echo "  Resource Group:    $TFSTATE_RG"
echo "  Storage Account:   $TFSTATE_SA"
echo "  Container:         $TFSTATE_CONTAINER"
echo "  Key:               lab.tfstate"
echo
echo "🔐 Add these GitHub Secrets for CI/CD:"
echo "  TFSTATE_STORAGE_ACCOUNT = $TFSTATE_SA"
echo "  TFSTATE_RESOURCE_GROUP  = $TFSTATE_RG"
echo "  TFSTATE_CONTAINER       = $TFSTATE_CONTAINER"
echo
echo "Grant your GitHub Actions service principal access to storage:"
echo "  az role assignment create \\"
echo "    --assignee-object-id <SP_OBJECT_ID> \\"
echo "    --assignee-principal-type ServicePrincipal \\"
echo "    --role \"Storage Blob Data Contributor\" \\"
echo "    --scope \"/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$TFSTATE_RG/providers/Microsoft.Storage/storageAccounts/$TFSTATE_SA\""
echo
echo "===================================================================="
echo "⚠️  IMPORTANT: State Migration After Initial Deployment"
echo "===================================================================="
echo
echo "If you deploy locally FIRST (with 'tofu apply'), then set up GitHub Actions:"
echo
echo "1. After successful local deployment, your state is in:"
echo "   envs/lab/terraform.tfstate"
echo
echo "2. The backend is configured, but OpenTofu won't migrate automatically."
echo "   You need to initialize with migration:"
echo
echo "   cd envs/lab"
echo "   tofu init -migrate-state"
echo
echo "3. This uploads your local state to Azure Storage."
echo
echo "4. Verify the state file was uploaded:"
echo "   az storage blob list --account-name $TFSTATE_SA \\"
echo "     --container-name $TFSTATE_CONTAINER --auth-mode key"
echo
echo "   The state file should be ~50KB+ (not empty!)"
echo
echo "5. Now GitHub Actions will use the same state."
echo
echo "⚠️  Alternative: Deploy from GitHub Actions FIRST"
echo "   - Set up service principal and secrets"
echo "   - Push to main branch"
echo "   - GitHub Actions creates infrastructure AND state"
echo "   - Then you can work locally with: tofu init"
echo
echo "===================================================================="
echo
