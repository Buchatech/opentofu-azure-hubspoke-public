# Azure Hub-Spoke with OpenTofu

> **Azure base network architecture solution** 

This repository contains a production-ready, modular OpenTofu configuration that deploys Azure hub-spoke network topology with **two deployment modes (private or public)** to match your requirements and budget.

**Note:** I wrote a blog regarding this solution that can be read here: https://www.buchatech.com/2026/01/azure-hub-and-spoke-architecture-explained-and-automated-with-opentofu. It has more information and the background on why I decided to buid this. 

---

## Architecture Overview

This solution deploys a **hub-and-spoke network architecture** (visual shows full-private deployment):
=======
> **Enterprise-grade Azure network architecture lab environment with Site-to-Site VPN, Azure Firewall, DNS Private Resolver, and core services**

This repository contains a production-ready, modular OpenTofu (Terraform) configuration that deploys a complete Azure hub-spoke network topology designed for hybrid cloud scenarios, connecting your on-premises network (e.g., UniFi network) to Azure.

## Architecture Overview

This lab deploys a **hub-and-spoke network architecture** following Azure best practices (visual shows full private deployment):


```
┌──────────────────────────────────────────────────────────────────────┐
│                            AZURE CLOUD                                │
│                                                                        │
│  ┌─── HUB VNet (rg-lab-hub-network) ────────────────────────┐        │
│  │ 10.10.0.0/16                                              │        │
│  │                                                            │        │
│  │  ┌──────────┐  ┌───────────┐  ┌────────────┐  ┌───────┐ │        │
│  │  │  Azure   │  │    VPN    │  │    DNS     │  │Jumpbox│ │        │
│  │  │ Firewall │  │  Gateway  │  │  Private   │  │  VM   │ │        │
│  │  │(10.10.1.0│  │(10.10.2.0)│  │  Resolver  │  │(Mgmt) │ │        │
│  │  │)+ DNAT   │  │           │  │(10.10.4-5.0│  │subnet │ │        │
│  │  │SSH:2222  │  │           │  │)           │  │       │ │        │
│  │  └─────┬────┘  └─────┬─────┘  └────────────┘  └───────┘ │        │
│  │        │             │                                     │        │
│  │        │             │  Site-to-Site VPN                  │        │
│  └────────┼─────────────┼─────────────────────────────────────┘        │
│           │             │                                               │
│           │  VNet Peering + Gateway Transit                            │
│           │             │                                               │
│  ┌────────▼─ SPOKE VNet (rg-lab-spoke1-network) ──────┐               │
│  │ 10.20.0.0/16                                        │               │
│  │                                                      │               │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │               │
│  │  │   Apps   │  │   APIs   │  │   Data/Services  │ │               │
│  │  │ Subnet   │  │ Subnet   │  │     Subnet       │ │               │
│  │  │          │  │          │  │  - ACR (Private) │ │               │
│  │  │          │  │          │  │  - Key Vault     │ │               │
│  │  └──────────┘  └──────────┘  └──────────────────┘ │               │
│  │                                                      │               │
│  │  Traffic routed through Azure Firewall ─────────────┘               │
│  └──────────────────────────────────────────────────────               │
│                                                                         │
│  ┌─── Management RG (rg-lab-management) ────────────┐                 │
│  │  - Azure Container Registry (ACR)                 │                 │
│  │  - Azure Key Vault                                 │                 │
│  │  - Private Endpoints in Spoke Data subnet         │                 │
│  └────────────────────────────────────────────────────┘                 │
│                                                                         │
└─────────────────────────────┬───────────────────────────────────────────┘
                              │
                      S2S VPN Tunnel (IPsec)
                              │
              ┌───────────────▼──────────────┐
              │   ON-PREMISES NETWORK        │
              │   (e.g., UniFi Router)       │
              │   192.168.1.0/24             │
              │                              │
              │   SSH → Azure Firewall:2222  │
              │   → DNAT → Jumpbox:22        │
              └──────────────────────────────┘
```

### Key Components

#### **Resource Organization**
Infrastructure is organized into **three separate resource groups** for better management and RBAC:

1. **Hub Network RG** (`rg-lab-hub-network`) - Core networking infrastructure
2. **Spoke Network RG** (`rg-lab-spoke1-network`) - Application network
3. **Management RG** (`rg-lab-management`) - Compute, services, and operational tools

#### **Network Architecture**

1. **Hub VNet (10.10.0.0/16)** - Central connectivity point
   - **Azure Firewall** for security and traffic inspection with DNAT rules
   - **VPN Gateway** for site-to-site connectivity to on-premises
   - **DNS Private Resolver** for hybrid DNS resolution
   - **Management subnet** with Ubuntu jumpbox VM (static IP: 10.10.3.10)

2. **Spoke VNet (10.20.0.0/16)** - Application workload network
   - **Apps** subnet (10.20.1.0/24) - Application tier
   - **APIs** subnet (10.20.2.0/24) - API/microservices tier
   - **Data** subnet (10.20.3.0/24) - Data tier and private endpoints

#### **Security & Access**

3. **Firewall-Based Security**
   - Azure Firewall in the hub for centralized traffic inspection
   - **DNAT rules** for secure jumpbox access (SSH port 2222 → 22)
   - Route tables forcing all spoke and hub management traffic through firewall
   - Configurable source IP restrictions for SSH access
   - Private endpoints for Azure services (no public access)

4. **Jumpbox (Bastion Host)**
   - **Ubuntu 22.04 LTS** VM in hub management subnet
   - **Static private IP** (10.10.3.10) for predictable firewall rules
   - **SSH-only authentication** (no passwords)
   - **Accessible via firewall DNAT**: `ssh -p 2222 user@<firewall-public-ip>`
   - Used for managing Azure VMs and testing connectivity

#### **Hybrid Connectivity**

5. **Site-to-Site VPN**
   - IPsec VPN tunnel connecting to your on-premises network
   - Gateway transit enabled (spoke can use hub's VPN Gateway)
   - DNS Private Resolver for seamless name resolution across environments

#### **Platform Services**

6. **Core Azure Services** (in Management RG)
   - **Azure Container Registry (ACR)** with private endpoint
   - **Azure Key Vault** with private endpoint
   - Private DNS zones for service resolution
   - All services accessible from jumpbox and on-premises via VPN

## 📋 Prerequisites

- **Azure Subscription** with appropriate permissions
- **Azure CLI** installed and configured
- **OpenTofu** (or Terraform) installed ([install guide](https://opentofu.org/docs/intro/install/))
- **On-Premises VPN Device** configured (e.g., UniFi Security Gateway)
- **Git** for version control (Github Recommended) ([Github.com](https://github.com/))
- **VS Code** for version an IDE to work with and run code ([code.visualstudio.com](https://code.visualstudio.com))

## 🚀 Deployment Modes

The bootstrap script supports two deployment modes to match your requirements:

### 🔐 FULL (private) Mode (Option 1 - Default)

**Best for:** Enterprise production-ready deployments with complete network isolation

**Includes:**
- ✅ Hub-Spoke network architecture with Azure Firewall
- ✅ **Private Endpoints** for Key Vault and Container Registry
- ✅ **Azure DNS Private Resolver** with on-premises DNS forwarding
- ✅ **Site-to-Site VPN Gateway** for hybrid connectivity
- ✅ **Optional Jumpbox** (Linux VM) for secure access
- ✅ Private DNS zones for privatelink endpoints
- ✅ VNet peering with custom routing through firewall
- ✅ DNAT rules for jumpbox SSH access through firewall


**Required Configuration Variables:**
- `subscription_id`, `tenant_id`
- `onprem_public_ip` - Your on-premises VPN endpoint public IP
- `vpn_shared_key` - Strong pre-shared key for VPN connection
- `onprem_dns_servers` - List of on-premises DNS server IPs
- `forward_domain_name` - Domain name to forward to on-prem DNS
- `acr_name`, `key_vault_name` (must be globally unique)

### 🌐 BASIC (public) Mode (Option 2)

**Best for:** Development, testing, learning, or cost-sensitive non-production environments

**Includes:**
- ✅ Hub-Spoke network architecture with Azure Firewall
- ✅ **Public access** for Key Vault and Container Registry
- ✅ VNet peering with routing through firewall
- ✅ Simplified configuration (fewer variables)

**Excludes:**
- ❌ DNS Private Resolver
- ❌ Site-to-Site VPN Gateway
- ❌ Jumpbox VM
- ❌ Private endpoints and DNS zones


**Required Configuration Variables:**
- `subscription_id`, `tenant_id`
- `acr_name`, `key_vault_name` (must be globally unique)

### 🔄 How to Choose Your Deployment Mode

When you run the bootstrap script, you'll be prompted:

```bash
Select deployment type:
  1) Full (Private endpoints, DNS Resolver, VPN, optional Jumpbox) [default]
  2) Basic (Public access, no DNS/VPN/Jumpbox)

Enter choice [1-2]:
```

### 📊 Module Comparison

| Module                   | FULL Mode | BASIC Mode |
|--------------------------|-----------|------------|
| `network-hub`            | ✅        | ✅         |
| `network-spoke`          | ✅        | ✅         |
| `peering-routing`        | ✅        | ✅         |
| `security-firewall`      | ✅ (with DNAT) | ✅ (no DNAT) |
| `services-core`          | ✅ (private) | ✅ (public) |
| `dns-private-resolver`   | ✅        | ❌         |
| `vpn-s2s`                | ✅        | ❌         |
| `compute-jumpbox`        | ✅ (optional) | ❌     |

### 🏷️ Custom Prefix Feature

The bootstrap script allows you to customize the naming of your resources with a unique prefix. This is particularly useful when:
- **Running multiple deployments** in the same subscription
- **Avoiding naming conflicts** with existing resources
- **Creating environment-specific deployments** (dev, test, prod)
- **Multiple users** deploying from the same repository

**How it works:**

When you run `bootstrap.sh`, you'll be prompted to enter a custom prefix:

```bash
Enter prefix [default: lab]: myproject
```

**Naming Convention:**

Your prefix will be used to create unique names for all resources:

| Resource Type | Naming Pattern | Example (prefix: "myproject") |
|--------------|----------------|-------------------------------|
| Repository Folder | `{prefix}-azure-lab-opentofu` | `myproject-azure-lab-opentofu` |
| Storage Account | `tfstate{prefix}{timestamp}` | `tfstatemyproject123456` |
| Resource Groups | `rg-tfstate-{prefix}` `rg-{prefix}-hub-network` | `rg-tfstate-myproject` `rg-myproject-hub-network` |

**Validation Rules:**

- ✅ Must be lowercase alphanumeric only (a-z, 0-9)
- ✅ Length: 3-15 characters
- ✅ No special characters, spaces, or uppercase letters
- ✅ Default value: `lab` (if you press Enter without typing)

**Examples:**

```bash
# Development environment
Enter prefix [default: lab]: dev
# Creates: dev-azure-lab-opentofu/, tfstatedev123456, rg-tfstate-dev

# Production environment
Enter prefix [default: lab]: prod
# Creates: prod-azure-lab-opentofu/, tfstateprod123456, rg-tfstate-prod

# Personal testing
Enter prefix [default: lab]: jsmith
# Creates: jsmith-azure-lab-opentofu/, tfstatejsmith123456, rg-tfstate-jsmith

# Use default
Enter prefix [default: lab]: 
# Creates: lab-azure-lab-opentofu/, tfstatelab123456, rg-tfstate-lab
```

> 💡 **Tip**: Choose a prefix that clearly identifies the purpose or owner of the deployment. This makes it easier to manage multiple deployments and track resources in Azure.

### 🔄 Switching Between Modes

#### Upgrading from BASIC to FULL

Upgrading requires re-running the bootstrap script and redeploying:

```bash
# 1. Destroy current BASIC deployment
cd envs/lab
tofu destroy

# 2. Re-run bootstrap with FULL mode
cd ../../bootstrap
./bootstrap.sh

# Select FULL mode and enter your prefix (same as before or new)

# 3. Configure terraform.tfvars with FULL mode variables
# Add: onprem_public_ip, vpn_shared_key, onprem_dns_servers, forward_domain_name

# 4. Navigate to the new repository (replace 'lab' with your prefix)
cd ../lab-azure-lab-opentofu/envs/lab

# 5. Deploy FULL infrastructure
tofu init
tofu apply
```

#### Downgrading from FULL to BASIC

Not recommended as it may leave resources orphaned. Better to destroy and redeploy:

```bash
# 1. Destroy FULL deployment completely (replace 'lab' with your prefix)
cd lab-azure-lab-opentofu/envs/lab
tofu destroy

# 2. Delete the generated repository
cd ../../..
rm -rf lab-azure-lab-opentofu

# 3. Re-run bootstrap with BASIC mode
cd bootstrap
./bootstrap.sh

# Select BASIC mode and enter your prefix (same as before or new)

# 4. Navigate to the new repository (replace 'lab' with your prefix)
cd ../lab-azure-lab-opentofu

# 5. Configure simplified terraform.tfvars (no VPN/DNS variables)

# 6. Deploy BASIC infrastructure
cd envs/lab
tofu init
tofu apply
```

## 🚀 Bootstrap Script Quick Start


### Step 1: Authenticate to Azure

```bash
# Login to Azure
--scope https://graph.microsoft.com/.default

# List available subscriptions
az account list -o table

# Set the subscription you want to use
az account set --subscription "<your-subscription-id-or-name>"

# Verify the active subscription and copy subscription ID and tenant ID for later use
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo Azure Subscription name = $SUBSCRIPTION_NAME
echo Subscription ID = $SUBSCRIPTION_ID
echo Tenant ID = $TENANT_ID
```

> 💡 **Tip**: It is recommended to run the Azure login and bootstrap script locally from VS code. After running it then push everything up to your GitHub repository. There will be instructions later on how to push up to the repository.

### Step 2: Generate Repository Structure with Remote State

The `bootstrap.sh` script scaffolds the entire project structure and sets up Azure Storage for remote state management:

```bash
# Run the bootstrap script
bash ./bootstrap.sh
```
When prompted, you'll be asked to:
1. **Choose deployment mode:**
Select deployment configuration:

  1) FULL    - Private endpoints, DNS Resolver, S2S VPN, Jumpbox"
  2) BASIC   - Public access, no DNS/VPN/Jumpbox (simplified)"

2. **Enter a custom prefix**: Enter a unique prefix/name for this deployment.`

Example interaction:
```
Enter selection (1 or 2) [default: 1]: 2
Enter prefix [default: lab]: myproject
```
<img width="848" height="821" alt="image" src="https://github.com/user-attachments/assets/2ac685dd-926a-41c5-93ea-a129974aecdc" />

This will create resources with your custom prefix:
- **Repository folder**: `myproject-azure-lab-opentofu/`
- **Storage Account**: `tfstatemyproject123456` (prefix + timestamp)
- **Resource Group**: `rg-tfstate-myproject`

<img width="809" height="1069" alt="image" src="https://github.com/user-attachments/assets/47530670-2876-4e6f-bcf3-da25145e91bb" />


> 💡 **Tip**: A companion file `bootstrap-steps.sh` is provided as a step-by-step walkthrough guide. This helper file contains detailed instructions, examples, and troubleshooting tips for running the bootstrap script and working with the infrastructure. Reference it if you need additional context or guidance during deployment.

**What gets created:**
- **Azure Storage Account** for OpenTofu state with your custom prefix
- Complete folder structure with 9 modular components (FULL) or 4 modules (BASIC)
- Starter OpenTofu configuration files with **backend configured**
- GitHub Actions workflow for CI/CD
- `.gitignore` for OpenTofu files
- Git repository with initial commit

**Important**: The script will output the storage account name (e.g., `tfstatemyproject123456`). Save this information - you'll need it for GitHub Actions setup.

### Why Remote State?

Remote state storage in Azure ensures:
- ✅ **State persistence** between GitHub Actions runs
- ✅ **State locking** to prevent concurrent modifications
- ✅ **Team collaboration** - multiple users can work on the same infrastructure
- ✅ **Secure storage** with encryption and RBAC

Without remote state, GitHub Actions would lose track of your infrastructure after each run, causing "resource already exists" errors.


### Step 3: Configure Your Environment

Navigate to the lab environment (replace `lab` with your custom prefix):

```bash
cd lab-azure-lab-opentofu/envs/lab
```

**Or if you used a custom prefix like "myproject":**
```bash
cd myproject-azure-lab-opentofu/envs/lab
```

Edit `terraform.tfvars` with your specific values.

**The required variables depend on your chosen deployment mode:**

#### For FULL Mode (Default):
=======
Edit `terraform.tfvars` with your specific values:

```terraform
subscription_id = "YOUR_SUBSCRIPTION_GUID"    # az account show --query id -o tsv
tenant_id       = "YOUR_TENANT_GUID"          # az account show --query tenantId -o tsv

# Your on-premises network details
onprem_public_ip      = "X.X.X.X"            # Your public WAN IP
onprem_address_spaces = ["192.168.1.0/24"]   # Your home/office network
vpn_shared_key        = "YOUR_SECURE_KEY"    # Must match your VPN device

# DNS Private Resolver settings
onprem_dns_servers  = ["192.168.1.1"]        # Your on-prem DNS server
forward_domain_name = "home.arpa."            # Your local domain

=======
# Must be globally unique and lowercase
acr_name       = "acrlabunique12345"
key_vault_name = "kvlabunique12345"

# Jumpbox configuration (optional - set enable_jumpbox = true to deploy)
enable_jumpbox             = false            # Toggle jumpbox deployment
jumpbox_private_ip         = "10.10.3.10"     # Static IP in management subnet
jumpbox_vm_size            = "Standard_DS1_v2" # VM size (reliable availability)
jumpbox_admin_username     = "azureuser"      # SSH username
jumpbox_ssh_public_key     = "ssh-ed25519 AAAA..."  # Your SSH public key

# Jumpbox firewall access (only applies when enable_jumpbox = true)
enable_jumpbox_dnat        = true             # Enable DNAT rule for SSH
jumpbox_inbound_port       = 2222             # External SSH port on firewall
jumpbox_allowed_ssh_source = ["0.0.0.0/0"]   # Source IPs for SSH (recommend your IP /32)

```

#### For BASIC Mode:

```terraform
subscription_id = "YOUR_SUBSCRIPTION_GUID"    # az account show --query id -o tsv
tenant_id       = "YOUR_TENANT_GUID"          # az account show --query tenantId -o tsv

# Must be globally unique and lowercase
acr_name       = "acrlabunique12345"
key_vault_name = "kvlabunique12345"

# Network CIDRs (optional - defaults provided)
hub_vnet_cidr   = ["10.0.0.0/16"]
spoke_vnet_cidr = ["10.1.0.0/16"]
=======

# Optional: Customize DNS settings
onprem_dns_servers  = ["192.168.1.1"]        # Your on-prem DNS server
forward_domain_name = "home.arpa."            # Your local domain
```

> **Important**: Replace the following placeholders:
> - `YOUR_SUBSCRIPTION_GUID` and `YOUR_TENANT_GUID` - Get from `az account show`
> - (FULL mode) `X.X.X.X` - Your on-premises public IP and your workstation IP for SSH
> - (FULL mode) `YOUR_SECURE_KEY` - Strong VPN shared key (must match UniFi configuration)
> - (FULL mode) `ssh-ed25519 AAAA...` - Your actual SSH public key from `~/.ssh/id_ed25519.pub` or `id_rsa.pub`
> - `acrlabunique12345` and `kvlabunique12345` - Globally unique names

### Step 4: Deploy the Infrastructure

```bash
# Format code
tofu fmt -recursive

# Initialize OpenTofu
tofu init -upgrade

# Validate configuration
tofu validate

# Review planned changes
tofu plan

# Deploy (confirm when prompted)
tofu apply
```

**Note:** If you selected full mode the deployment takes approximately **30-45 minutes** due to VPN Gateway provisioning.

## 📁 Repository Structure

```
azure-lab-opentofu/
├── envs/
│   └── lab/                          # Lab environment configuration
│       ├── main.tf                   # Main orchestration file
│       ├── variables.tf              # Input variable definitions
│       ├── terraform.tfvars          # Variable values (customize this!)
│       └── outputs.tf                # Output values
│
├── modules/                          # Reusable infrastructure modules
│   ├── network-hub/                  # Hub VNet with specialized subnets
│   │   ├── main.tf                   # Hub VNet, subnets (Firewall, Gateway, DNS, Mgmt)
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── network-spoke/                # Spoke VNet for workloads
│   │   ├── main.tf                   # Spoke VNet with Apps/APIs/Data subnets
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── compute-jumpbox/              # Ubuntu jumpbox VM
│   │   ├── main.tf                   # Linux VM with static IP, SSH key auth
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── security-firewall/            # Azure Firewall with DNAT
│   │   ├── main.tf                   # Firewall with public IP, DNAT rules
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── hub-routing/                  # Hub subnet routing
│   │   ├── main.tf                   # Route table for management subnet
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── vpn-s2s/                      # Site-to-Site VPN
│   │   ├── main.tf                   # VPN Gateway, Local Gateway, Connection
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── peering-routing/              # VNet peering and spoke routing
│   │   ├── main.tf                   # Hub-spoke peering, spoke route tables
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── dns-private-resolver/         # DNS Private Resolver
│   │   ├── main.tf                   # Resolver with inbound/outbound endpoints
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── services-core/                # Core Azure services
│       ├── main.tf                   # ACR, Key Vault with private endpoints
│       ├── variables.tf
│       └── outputs.tf
│
├── .github/
│   └── workflows/
│       └── tofu.yml                  # CI/CD pipeline for OpenTofu
│
└── .gitignore                        # Ignore Terraform state and lock files
```

## 🔧 Module Breakdown

### 1. Network Hub (`modules/network-hub`)

**Purpose**: Creates the central hub VNet that serves as the connectivity point for all resources.

**What it does**:
- Creates Hub VNet (10.10.0.0/16)
- **AzureFirewallSubnet** (10.10.1.0/26) - Reserved for Azure Firewall
- **GatewaySubnet** (10.10.2.0/27) - Reserved for VPN Gateway
- **Management** subnet (10.10.3.0/24) - For jump boxes, bastion hosts
- **DnsInbound** subnet (10.10.4.0/28) - For DNS Private Resolver inbound endpoint
- **DnsOutbound** subnet (10.10.5.0/28) - For DNS Private Resolver outbound endpoint

**Key features**:
- Subnet delegations for DNS Private Resolver endpoints
- Outputs VNet ID, subnet IDs for other modules to consume

### 2. Network Spoke (`modules/network-spoke`)

**Purpose**: Creates the spoke VNet for application workloads.

**What it does**:
- Creates Spoke VNet (10.20.0.0/16)
- **Apps** subnet (10.20.1.0/24) - Application tier
- **APIs** subnet (10.20.2.0/24) - API/microservices tier
- **Data** subnet (10.20.3.0/24) - Data tier and private endpoints

**Key features**:
- Private endpoint network policies disabled on all subnets
- Structured for multi-tier application deployment

### 3. Compute Jumpbox (`modules/compute-jumpbox`)

**Purpose**: Deploys a secure Ubuntu Linux jumpbox/bastion host for managing Azure resources.

**What it does**:
- Creates a network interface with **static private IP** (10.10.3.10)
- Deploys Ubuntu 22.04 LTS virtual machine
- Configures SSH-only authentication (no passwords)
- Uses provided SSH public key for access
- Placed in hub management subnet
- **Optional deployment** - controlled by `enable_jumpbox` variable

**Key features**:
- **Fully optional** - Set `enable_jumpbox = false` to skip deployment entirely
- **Static IP** ensures firewall DNAT rules are stable and predictable
- Standard_DS1_v2 VM size (reliable availability in most Azure regions)
- **SSH key authentication only** - more secure than passwords
- Used for accessing Azure VMs, testing connectivity, and administrative tasks
- Can reach on-premises via VPN and all Azure services via private endpoints

**Typical uses**:
- SSH gateway to other Azure VMs
- Testing network connectivity and DNS resolution
- Running Azure CLI commands in a cloud environment
- Accessing private endpoint services (ACR, Key Vault)

### 4. Security Firewall (`modules/security-firewall`)

**Purpose**: Deploys Azure Firewall for centralized network security with optional DNAT rules for jumpbox access.

**What it does**:
- Creates a Standard SKU public IP
- Deploys Azure Firewall (Standard tier)
- Attaches firewall to the hub's AzureFirewallSubnet
- **Conditionally creates DNAT rule** to forward external SSH (port 2222) to jumpbox (port 22)
- **Conditionally creates network allow rule** for SSH traffic to jumpbox
- Configurable source IP restrictions for SSH access
- DNAT rules only created when **both** `enable_jumpbox = true` AND `enable_jumpbox_dnat = true`

**Key features**:
- Centralized egress and inspection point
- **DNAT (Destination NAT)** translates `firewall-ip:2222` → `jumpbox:22` (when enabled)
- Fully optional jumpbox integration - firewall works standalone without jumpbox
- Outputs private IP (used by route tables) and public IP
- Secure jumpbox access without exposing VM directly to internet

**Security model** (when jumpbox enabled):
```
Internet → Firewall Public IP:2222 → DNAT → Jumpbox 10.10.3.10:22
             (Restricted by source IP)
```

### 5. Hub Routing (`modules/hub-routing`)

**Purpose**: Forces hub management subnet traffic through the firewall for security inspection.

**What it does**:
- Creates route table for hub management subnet
- Adds default route (0.0.0.0/0) pointing to firewall private IP
- Associates route table with management subnet
- Ensures jumpbox egress traffic is inspected by firewall

**Key features**:
- Consistent security policy - all hub traffic (like spoke) goes through firewall
- Jumpbox internet access is controlled and monitored
- Enables firewall logging and inspection of management traffic

### 6. VPN Site-to-Site (`modules/vpn-s2s`)

**Purpose**: Deploys Azure Firewall for centralized network security and traffic inspection.

**What it does**:
- Creates a Standard SKU public IP
- Deploys Azure Firewall (Standard tier)
- Attaches firewall to the hub's AzureFirewallSubnet

**Key features**:
- Centralized egress and inspection point
- Outputs private IP (used by route tables) and public IP

### 4. VPN Site-to-Site (`modules/vpn-s2s`)

**Purpose**: Establishes secure IPsec VPN connection to your on-premises network.

**What it does**:
- Creates a dynamic public IP for the VPN Gateway
- Deploys Azure VPN Gateway (configurable SKU, default VpnGw1)
- Creates Local Network Gateway (represents your on-premises VPN device)
- Establishes VPN connection with shared key

**Key features**:
- Route-based VPN type for flexibility
- IPsec tunnel encryption
- Connects Azure VNet to on-premises (e.g., UniFi router)

**On-premises requirements**:
- Your router's public IP
- VPN shared key (must match on both sides)
- IPsec/IKEv2 support

### 5. Peering & Routing (`modules/peering-routing`)

**Purpose**: Connects hub and spoke VNets and forces traffic through the firewall.

**What it does**:
- Creates bidirectional VNet peering between hub and spoke
- Hub allows gateway transit (spoke can use VPN Gateway)
- Spoke uses remote gateways (for VPN connectivity)
- Creates route table with default route (0.0.0.0/0) to Azure Firewall
- Associates route table with all spoke subnets

**Key features**:
- Forces all spoke traffic through the firewall for inspection
- Enables spoke to communicate with on-premises via hub's VPN Gateway

### 6. DNS Private Resolver (`modules/dns-private-resolver`)

**Purpose**: Enables hybrid DNS resolution between Azure and on-premises.

**What it does**:
- Creates Azure DNS Private Resolver in the hub
- **Inbound endpoint** - Allows on-premises to query Azure DNS
- **Outbound endpoint** - Allows Azure to forward queries to on-premises DNS
- Creates forwarding ruleset for your on-premises domain (e.g., `home.arpa.`)
- Links ruleset to hub and spoke VNets

**Key features**:
- Seamless DNS resolution across hybrid environments
- Conditional forwarding to on-premises DNS server
- Resolves private endpoint DNS names automatically

**How it works**:
- Azure VMs can resolve on-premises hostnames (e.g., `server.home.arpa`)
- On-premises devices can resolve Azure private endpoints
- No need for custom DNS servers in VNets

### 7. Services Core (`modules/services-core`)

**Purpose**: Deploys core Azure PaaS services with private connectivity.

**What it does**:
- Creates **Azure Container Registry** (ACR) - Standard SKU, no public access
- Creates **Azure Key Vault** - Standard SKU, no public access, soft delete enabled
- Creates private DNS zones:
  - `privatelink.azurecr.io` - For ACR
  - `privatelink.vaultcore.azure.net` - For Key Vault
- Links private DNS zones to hub and spoke VNets
- Creates private endpoints in spoke's Data subnet
- Integrates private endpoints with private DNS zones

**Key features**:
- No public internet access to ACR or Key Vault
- Automatic DNS resolution via private endpoints
- Accessible from Azure VMs and on-premises (via VPN)

## 🔐 Security Features

### Network Security
- ✅ Azure Firewall inspects all egress traffic from spoke
- ✅ Route tables force traffic through firewall (both spoke and hub management subnet)
- ✅ No direct internet access from spoke subnets
- ✅ **Jumpbox access** via DNAT only - not directly exposed to internet
- ✅ **Source IP restrictions** can be configured for SSH access (firewall DNAT rule)
- ✅ **Port translation** (external 2222 → internal 22) obscures SSH service

### Jumpbox Security

- ✅ **Fully optional deployment** - Set `enable_jumpbox = false` to skip entirely
- ✅ **SSH key-only authentication** - password auth disabled
- ✅ **Static private IP** (10.10.3.10) - no public IP assigned
- ✅ **Firewall DNAT** provides controlled external access (optional)
- ✅ **Dual-layer control** - DNAT only active when `enable_jumpbox = true` AND `enable_jumpbox_dnat = true`
- ✅ **Hub routing** forces jumpbox egress through firewall for inspection
- ✅ **Management subnet isolation** - separate from application workloads
- ✅ **VM size flexibility** - Standard_DS1_v2 default, easily changed if SKU unavailable

### Service Security
- ✅ ACR and Key Vault have public access disabled
- ✅ Private endpoints used for all PaaS services
- ✅ Private DNS zones for secure name resolution

### Secrets Management
- ✅ VPN shared key marked as sensitive in variables
- ✅ Key Vault ready for application secrets
- ✅ `.gitignore` prevents committing state files

## 📤 Outputs

After deployment, OpenTofu outputs key information:

```bash
tofu output
```

| Output | Description | Use Case |
|--------|-------------|----------|
| `firewall_public_ip` | Azure Firewall's public IP | Monitoring, firewall rules, **SSH to jumpbox (if enabled)** |
| `firewall_private_ip` | Firewall's internal IP | Routing configuration |
| `vpn_gateway_public_ip` | VPN Gateway's public IP | **Configure in your on-premises VPN device** |
| `jumpbox_private_ip` | Jumpbox internal IP | 10.10.3.10 (static) - `null` if disabled |
| `jumpbox_ssh_via_firewall` | Complete SSH command | **Connect to jumpbox via DNAT** - `null` if disabled |
| `jumpbox_status` | Deployment status message | Helpful guidance for SKU capacity issues |
| `dns_inbound_endpoint_ip` | DNS resolver inbound IP | Configure on-prem DNS to forward to Azure |
| `acr_login_server` | Container registry URL | Docker login, image push/pull |
| `key_vault_uri` | Key Vault URL | Secret management, app configuration |

**Example jumpbox SSH access** (when `enable_jumpbox = true`):
```bash
# Get the SSH command
tofu output jumpbox_ssh_via_firewall

# Example output:
# ssh -p 2222 azureuser@<firewall-public-ip>

# This DNAT rule translates:
# firewall-public-ip:2222 → jumpbox 10.10.3.10:22
```

**Note**: If jumpbox is disabled (`enable_jumpbox = false`), jumpbox-related outputs will return `null`.

## 🌐 On-Premises VPN Configuration (UniFi Example)

After deployment you can now configure your on-premises VPN device. Note that your on-premises VPN will differ based on the VPN solution you have. Confguration steps using the Unifi example are as follows:

### Get the Azure VPN Gateway IP

```bash
cd azure-lab-opentofu/envs/lab
tofu output vpn_gateway_public_ip
```

### UniFi Settings (Settings → VPN → Site-to-Site VPN)

1. **Remote Gateway** = Azure VPN Gateway Public IP (from output above)
2. **Pre-Shared Key** = Same key you used in `terraform.tfvars`
3. **Local Network** = Your home network (e.g., `192.168.1.0/24`)
4. **Remote Networks** = Azure VNets:
   - Hub: `10.10.0.0/16`
   - Spoke: `10.20.0.0/16`

### Verify Connection

From Azure Portal:
1. Navigate to **Virtual Network Gateways**
2. Select your gateway (`lab-vpngw`)
3. Go to **Connections**
4. Status should show **Connected**

Test connectivity:
```bash
# From on-premises, ping an Azure VM
ping 10.20.1.10  # Example Azure VM IP

# From Azure VM, ping on-premises
ping 192.168.1.100  # Example on-prem device
```

## 🔐 Azure Point-to-Site VPN Client Setup

If you need to connect to the Azure environment from your laptop when not on the corporate network, you can set up Azure Point-to-Site (P2S) VPN. This allows direct VPN connection from individual devices to Azure.

> **Note**: The current OpenTofu configuration deploys **Site-to-Site VPN** only. To enable Point-to-Site VPN, you'll need to add P2S configuration to the VPN Gateway.

### Prerequisites

Before setting up P2S VPN, you need to:
1. Configure P2S on your VPN Gateway (requires additional OpenTofu configuration)
2. Generate client certificates (for certificate-based auth) OR configure Azure AD authentication

### Option 1: Add P2S Configuration to VPN Gateway (Certificate Auth)

**Step 1: Generate Root and Client Certificates**

On Windows (PowerShell as Administrator):

```powershell
# Generate root certificate
$cert = New-SelfSignedCertificate `
  -Type Custom `
  -KeySpec Signature `
  -Subject "CN=AzureVPNRootCert" `
  -KeyExportPolicy Exportable `
  -HashAlgorithm sha256 `
  -KeyLength 2048 `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -KeyUsageProperty Sign `
  -KeyUsage CertSign

# Generate client certificate from root
New-SelfSignedCertificate `
  -Type Custom `
  -DnsName "AzureVPNClientCert" `
  -KeySpec Signature `
  -Subject "CN=AzureVPNClientCert" `
  -KeyExportPolicy Exportable `
  -HashAlgorithm sha256 `
  -KeyLength 2048 `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -Signer $cert `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

# Export root certificate public key (upload this to Azure)
$rootCertBase64 = [Convert]::ToBase64String($cert.RawData)
Write-Output $rootCertBase64 | Out-File -FilePath "$env:USERPROFILE\Desktop\AzureVPNRootCert.txt"
```

On macOS/Linux:

```bash
# Generate root certificate and key
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout azure-vpn-root.key \
  -out azure-vpn-root.crt \
  -days 3650 \
  -subj "/CN=AzureVPNRootCert"

# Generate client certificate and key
openssl req -newkey rsa:2048 -nodes \
  -keyout azure-vpn-client.key \
  -out azure-vpn-client.csr \
  -subj "/CN=AzureVPNClientCert"

# Sign client certificate with root
openssl x509 -req -in azure-vpn-client.csr \
  -CA azure-vpn-root.crt \
  -CAkey azure-vpn-root.key \
  -CAcreateserial \
  -out azure-vpn-client.crt \
  -days 3650 \
  -extfile <(echo "extendedKeyUsage=clientAuth")

# Get base64 encoded root cert (upload this to Azure)
cat azure-vpn-root.crt | grep -v "CERTIFICATE" | tr -d '\n' > azure-vpn-root-base64.txt
cat azure-vpn-root-base64.txt
```

**Step 2: Configure P2S on VPN Gateway via Azure Portal**

1. Go to **Azure Portal** → **Virtual network gateways** → Your gateway (`lab-vpngw`)
2. Click **Point-to-site configuration**
3. Click **Configure now**
4. Configure the following:
   - **Address pool**: `172.16.0.0/24` (VPN client IP range, must not overlap with hub/spoke)
   - **Tunnel type**: **IKEv2 and OpenVPN (SSL)**
   - **Authentication type**: **Azure certificate**
   - **Root certificate name**: `AzureVPNRootCert`
   - **Public certificate data**: Paste the base64 string from Step 1
5. Click **Save** (this may take 10-15 minutes)

**Step 3: Download VPN Client**

1. After P2S configuration is saved, click **Download VPN client**
2. Extract the downloaded ZIP file
3. **Windows**: Run `WindowsAmd64/VpnClientSetupAmd64.exe`
4. **macOS**: Import `Generic/VpnServerRoot.cer` and client cert into Keychain, configure VPN in System Preferences
5. **Linux**: Use the `Generic/VpnSettings.xml` with NetworkManager or strongSwan

**Step 4: Connect to Azure VPN**

Windows:
1. Go to **Settings** → **Network & Internet** → **VPN**
2. You'll see a new VPN connection named after your VNet
3. Click **Connect**
4. Your client certificate will be used for authentication

macOS/Linux:
1. Configure VPN client with the settings from `VpnSettings.xml`
2. Import client certificate
3. Connect using native VPN client or OpenVPN

### Option 2: P2S with Azure AD Authentication (Recommended for Enterprise)

This method uses Azure AD for authentication (no certificates needed).

**Step 1: Register Azure VPN Application in Azure AD**

```bash
# Use the pre-registered Azure VPN application
# This is a Microsoft-provided app available in all Azure AD tenants
AZURE_VPN_APP_ID="41b23e61-6c1e-4545-b367-cd054e0ed4b4"

# Grant admin consent (one-time, requires admin)
az ad app permission grant \
  --id $AZURE_VPN_APP_ID \
  --api 00000003-0000-0000-c000-000000000000
```

**Step 2: Configure P2S with Azure AD via Azure Portal**

1. Go to **Virtual network gateways** → Your gateway → **Point-to-site configuration**
2. **Address pool**: `172.16.0.0/24`
3. **Tunnel type**: **OpenVPN (SSL)**
4. **Authentication type**: **Azure Active Directory**
5. **Tenant**: `https://login.microsoftonline.com/{YOUR-TENANT-ID}/`
6. **Audience**: `41b23e61-6c1e-4545-b367-cd054e0ed4b4`
7. **Issuer**: `https://sts.windows.net/{YOUR-TENANT-ID}/`
8. Click **Save**

**Step 3: Download Azure VPN Client**

1. Download **Azure VPN Client** from:
   - Windows: Microsoft Store
   - macOS: App Store
   - Linux: [Download from Microsoft](https://aka.ms/azvpnclientdownload)

2. After P2S configuration is saved in Azure Portal, click **Download VPN client**
3. Extract and open the `AzureVPN` folder
4. Import the `azurevpnconfig.xml` file into Azure VPN Client

**Step 4: Connect**

1. Open Azure VPN Client
2. Click **+** → **Import**
3. Select the `azurevpnconfig.xml` file
4. Click **Connect**
5. Sign in with your Azure AD credentials
6. You're now connected to Azure!

### Verify P2S VPN Connection

Once connected, test connectivity:

```bash
# Check your VPN IP (should be in the 172.16.0.0/24 range)
# Windows
ipconfig | findstr "172.16"

# macOS/Linux
ifconfig | grep "172.16"

# Test connectivity to Azure resources
ping 10.10.0.1        # Hub VNet gateway
ping 10.20.1.10       # Example spoke VM
ping 10.10.3.10       # Jumpbox (if enabled)

# Test DNS resolution
nslookup server.home.arpa  # Should resolve via Azure DNS
```

### Troubleshooting P2S VPN

**Problem**: "The VPN client is not configured" error

**Solution**: Ensure P2S configuration is complete on the VPN Gateway and you've downloaded the latest VPN client configuration.

**Problem**: Certificate authentication fails

**Solution**: 
- Verify root certificate is uploaded correctly to Azure
- Ensure client certificate is installed in your personal certificate store
- Check that client certificate chains to the root certificate

**Problem**: Can connect but can't access resources

**Solution**:
```bash
# Check your routing table (Windows)
route print

# Verify Azure routes are added for 10.10.0.0/16 and 10.20.0.0/16
# Check NSG rules allow traffic from P2S address pool (172.16.0.0/24)
```

**Problem**: Azure AD authentication fails

**Solution**:
- Verify you're using the correct tenant ID
- Ensure the Azure VPN app has admin consent
- Check that your user account has access to the subscription

### P2S vs S2S VPN Comparison

| Feature | Point-to-Site (P2S) | Site-to-Site (S2S) |
|---------|---------------------|---------------------|
| **Use Case** | Individual laptops/devices | On-premises network gateway |
| **Setup** | Per-device VPN client | Router/firewall configuration |
| **Authentication** | Certificates or Azure AD | Pre-shared key (IPSec) |
| **Users** | Remote workers, contractors | Entire office network |
| **Address Pool** | 172.16.0.0/24 (P2S range) | On-premises CIDR (192.168.x.x) |
| **Concurrent** | Up to 10,000 connections (SKU dependent) | Single tunnel, always-on |

> **Best Practice**: Use **both** P2S and S2S together. S2S connects your office network to Azure, while P2S allows individual remote workers to connect from anywhere.

## 🔄 Push to GitHub Repository and use GitHub Actions for CI/CD

After running the `bootstrap.sh` script and customizing your configuration, you'll need to push your code to GitHub. Also this generated repository structure includes a GitHub Actions workflow (`.github/workflows/tofu.yml`) for automated deployment using OpenID Connect (OIDC) for secure, passwordless authentication to Azure. Follow the steps to configure your GitHub for the Actions workflow and push your code up to your GitHub repository.

=======
## � Create a New GitHub Repository

After running the `bootstrap.sh` script and customizing your configuration, you'll need to push your code to GitHub. The next thing you will want to do is make sure you have a Git Hub Repository. Here's how to do it:

1. **Create a new repository on GitHub**:
   - Go to [github.com/new](https://github.com/new)
   - Name it (e.g., `lab-azure-lab-opentofu` or use your custom prefix)
   - Choose **Private** repository
   - Do **NOT** initialize with README, .gitignore, or license
   - Click **Create repository**

## 🔄 GitHub Actions CI/CD

After you push the code to the new repository the code will include a GitHub Actions workflow (`.github/workflows/tofu.yml`) for automated deployment using OpenID Connect (OIDC) for secure, passwordless authentication to Azure.

### Workflow Triggers

- **Pull Request**: Runs `tofu fmt`, `init`, `validate`, and `plan`
- **Push to main**: Runs full deployment with `tofu apply`

### Step 1: Create Azure Service Principal with Federated Credentials

> **🖥️ Where to Run This**: Run these commands from your **local terminal** (bash, PowerShell, or any shell where you have Azure CLI installed).
>
> **Prerequisites**:
> - Azure CLI installed
> - Logged into Azure: `az login`
> - Correct subscription selected: `az account set --subscription "YOUR_SUBSCRIPTION"`

Create a service principal that GitHub Actions can use to authenticate to Azure via OIDC:

```bash
# Set variables (replace with your values)
GITHUB_ORG="YourGitHubUsername"      
GITHUB_REPO="customprefix-azure-lab-opentofu"  # Your repo name with custom prefix
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
APP_NAME="customprefix-azure-lab-opentofu" # Use repo name with custom prefix

# Create the service principal
az ad app create --display-name $APP_NAME

# Get the Application (client) ID
CLIENT_ID=$(az ad app list --display-name $APP_NAME --query "[0].appId" -o tsv)
OBJECT_ID=$(az ad app list --display-name $APP_NAME --query "[0].id" -o tsv)

# Create a service principal for the app
az ad sp create --id $CLIENT_ID

# Add federated credential for GitHub Actions (main branch)
az ad app federated-credential create \
  --id $OBJECT_ID \
  --parameters "{
    \"name\": \"github-actions-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main\",
    \"description\": \"GitHub Actions - main branch\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Add federated credential for GitHub Actions (pull requests)
az ad app federated-credential create \
  --id $OBJECT_ID \
  --parameters "{
    \"name\": \"github-actions-pr\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request\",
    \"description\": \"GitHub Actions - pull requests\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Assign Contributor role to the service principal on your subscription
az role assignment create \
  --assignee $CLIENT_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID

# Get the service principal object ID for storage access
SP_OBJECT_ID=$(az ad sp show --id $CLIENT_ID --query id -o tsv)

# Grant service principal access to state storage (from bootstrap.sh output)
# Replace STORAGE_ACCOUNT_NAME with the value from bootstrap.sh output
STORAGE_ACCOUNT_NAME="tfstate12345"  # ⚠️ REPLACE with your actual storage account name
TFSTATE_RG="rg-tfstate"

az role assignment create \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$TFSTATE_RG/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME"

# Display the values you'll need for GitHub Secrets
echo "======================================"
echo "GitHub Secrets Configuration:"
echo "======================================"
echo "AZURE_CLIENT_ID: $CLIENT_ID"
echo "AZURE_TENANT_ID: $(az account show --query tenantId -o tsv)"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo ""
echo "State Storage (from bootstrap.sh):"
echo "TFSTATE_STORAGE_ACCOUNT: $STORAGE_ACCOUNT_NAME"
echo "TFSTATE_RESOURCE_GROUP: $TFSTATE_RG"
echo "TFSTATE_CONTAINER: tfstate"
echo "======================================"
```

> **💡 Important Notes**:
> - **You only run this ONCE** - It creates the Azure resources needed for GitHub Actions
> - **Replace STORAGE_ACCOUNT_NAME** - Use the actual storage account name from `bootstrap.sh` output
> - **Requires permissions** - You need Azure AD permissions to create service principals
> - **Save the output** - Copy all values for GitHub Secrets (Step 2)
> - **Security** - These credentials use OIDC (no passwords stored in GitHub)
> - **Storage access is critical** - Without it, GitHub Actions cannot read/write state files

### Step 2: Configure GitHub Repository Secrets

Go to your GitHub repository:

1. Navigate to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add the following secrets (from Step 1 output and bootstrap.sh output):

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AZURE_CLIENT_ID` | From step 1 output | Service Principal Application ID |
| `AZURE_TENANT_ID` | From step 1 output | Your Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | From step 1 output | Your Azure subscription ID |
| `TFSTATE_STORAGE_ACCOUNT` | From bootstrap.sh output | State storage account name (e.g., `tfstatelab123456` or `tfstate{your-prefix}123456`) |
| `TFSTATE_RESOURCE_GROUP` | `rg-tfstate-{prefix}` | State storage resource group (e.g., `rg-tfstate-lab` or `rg-tfstate-myproject`) |
| `TFSTATE_CONTAINER` | `tfstate` | State storage container name |

> **Note**: The last three secrets are for remote state management. GitHub Actions needs these to access the Azure Storage Account where your OpenTofu state is stored. The resource group and storage account names will include your custom prefix if you specified one during bootstrap.

### Step 3: Push Code to GitHub

 Now that you have your GitHub repository and the action secrets set next we need to push our code to the repository. Here's how to do it from VS Code or your terminal:

### Option 1: Push to New Repository

1. **Initialize Git and push from your local folder**:

```bash
# Navigate to your project folder (replace 'lab' with your prefix)
cd lab-azure-lab-opentofu

# Initialize Git repository (if not already done by bootstrap.sh)
git init

# Add the GitHub repository as remote
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git

# Create and switch to main branch
git checkout -b main

# Stage all files
git add -A

# Commit with descriptive message
git commit -m "Initial commit: Azure hub-spoke infrastructure with OpenTofu"

# Set main branch
git branch -M main

# Push to GitHub
git push -u origin main
```

### Option 2: Push to Feature Branch

If you already have a repository and want to push to a specific branch:

```bash
# Navigate to your project folder
cd azure-lab-opentofu

# Initialize Git if needed
git init

# Add remote (skip if already added)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git

# Fetch existing branches
git fetch origin

# Create and switch to your feature branch
git checkout -b Az-Storage-for-state-Mgt

# If the branch exists remotely, pull and merge
git pull origin Az-Storage-for-state-Mgt --allow-unrelated-histories

# Stage all files
git add -A

# Commit your changes
git commit -m "Add Azure Storage backend for remote state management

- Integrated Azure Storage Account creation into bootstrap.sh
- Updated bootstrap-steps.sh with storage access commands
- Updated README.md with comprehensive remote state documentation
- Configured backend block in main.tf for state management"

# Push to GitHub
git push -u origin Az-Storage-for-state-Mgt
```

### Using VS Code Source Control

If you prefer using VS Code's built-in Git tools:

1. **Open VS Code** in your project folder
2. **Source Control panel** (Ctrl+Shift+G or Cmd+Shift+G on Mac)
3. **Stage changes**: Click the `+` icon next to "Changes"
4. **Commit**: Enter commit message and click the checkmark ✓
5. **Publish/Push**: Click "Publish Branch" or "Push" button in the status bar

### Important Notes

> ⚠️ **Before pushing**:
> - Ensure `terraform.tfvars` does **NOT** contain sensitive data (VPN keys, passwords)
> - Verify `.gitignore` excludes `.tfstate` files and secrets
> - Review what's being committed: `git status`

> 💡 **Authentication**:
> - For HTTPS: You'll be prompted for GitHub username and Personal Access Token (PAT)
> - For SSH: Set up SSH keys first: [GitHub SSH setup](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
> - Recommended: Use SSH for easier authentication

> 📋 **Next Steps After Pushing**:
> - Create a Pull Request if using feature branches
> - Set up GitHub Actions (see next section)
> - Add required GitHub Secrets for CI/CD

=======

### Step 3.5: State Migration (If You Deployed Locally First)

> ⚠️ **CRITICAL**: If you deployed infrastructure locally with `tofu apply` BEFORE setting up GitHub Actions, you must migrate your state to Azure Storage.

**Why?** Your local state file contains all your deployed resources. If you don't migrate it to Azure Storage, GitHub Actions will start with an empty state and try to create everything again, causing "resource already exists" errors.

**How to migrate:**

1. **Check if you have a local state file:**
```bash
cd azure-lab-opentofu/envs/lab
ls -lh terraform.tfstate*
```

If you see `terraform.tfstate` or `terraform.tfstate.backup` with meaningful size (50KB+), you need to migrate.

2. **Initialize with state migration:**
```bash
cd azure-lab-opentofu/envs/lab
tofu init -migrate-state
```

OpenTofu will ask: `Do you want to copy existing state to the new backend?`  
Type `yes` and press Enter.

3. **Verify the state was uploaded to Azure Storage:**
```bash
az storage blob list \
  --account-name <TFSTATE_STORAGE_ACCOUNT> \
  --container-name tfstate \
  --auth-mode key \
  --query "[].{name:name, size:properties.contentLength}" -o table
```

You should see `lab.tfstate` with a size around 50KB or more (not empty!).

4. **Optional: Remove local state files (they're now in Azure Storage):**
```bash
rm terraform.tfstate terraform.tfstate.backup
```

**Alternative Approach: Deploy from GitHub Actions First**

If you haven't deployed locally yet:
1. Skip local deployment
2. Set up service principal and GitHub Secrets (Steps 1-2)
3. Push code to GitHub (Step 3)
4. Let GitHub Actions deploy everything
5. Then you can work locally by running `tofu init` (it will use the state from Azure Storage)

This approach is cleaner and avoids state migration!

### Step 4: Trigger GitHub Actions Workflow

**Option 1: Automatic trigger on push to main**
```bash
# Make a change, commit, and push
git add .
git commit -m "Update infrastructure configuration"
git push
```

**Option 2: Create a Pull Request**
```bash
# Create a new branch
git checkout -b feature/update-firewall-rules

# Make changes to .tf files
# ... edit files ...

# Commit and push
git add .
git commit -m "Add new firewall rules"
git push -u origin feature/update-firewall-rules

# Go to GitHub and create a Pull Request
# The workflow will run automatically and comment the plan
```

**Option 3: Manual trigger via GitHub UI**
1. Go to your repository on GitHub
2. Click **Actions** tab
3. Select the **opentofu** workflow
4. Click **Run workflow** dropdown (requires workflow_dispatch trigger - add to workflow if needed)

### Step 5: Monitor Workflow Execution

1. Go to **Actions** tab in your GitHub repository
2. Click on the running workflow
3. View logs for each step:
   - **Plan job** (on PR): Shows `tofu plan` output
   - **Apply job** (on push to main): Shows `tofu apply` output
4. Check for errors or warnings in the logs

### Workflow Features

- ✅ **OIDC Authentication** - No secrets or passwords stored
- ✅ **Automatic formatting checks** - Ensures code style consistency
- ✅ **Validation on every PR** - Catches errors before merge
- ✅ **Plan preview** - See changes before applying
- ✅ **Auto-apply on main** - Automatic deployment on merge
- ✅ **Working directory** - Runs from `envs/lab` automatically

### Troubleshooting GitHub Actions

**Problem**: Workflow fails with "AADSTS700016: Application not found"

**Solution**: Verify federated credentials are set correctly:
```bash
# List federated credentials
az ad app federated-credential list --id $OBJECT_ID

# Verify the subject matches your GitHub org/repo exactly
```

**Problem**: "Unauthorized" error during Azure login

**Solution**: Verify role assignment:
```bash
# Check role assignments for the service principal
az role assignment list --assignee $CLIENT_ID --output table

# Re-assign if needed
az role assignment create \
  --assignee $CLIENT_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID
```

**Problem**: Workflow runs but `tofu init` fails

**Solution**: Check if backend is configured. For first-time setup, ensure you're using local backend or configure remote backend in `envs/lab/main.tf`.

## 🧪 Testing & Validation

### After Deployment

```bash
# Check all outputs
tofu output

# Verify VPN connection status
az network vnet-gateway show \
  --name lab-vpngw \
  --resource-group rg-lab-hubspoke \
  --query "vpnClientConfiguration"

# Check firewall status
az network firewall show \
  --name lab-azfw \
  --resource-group rg-lab-hubspoke \
  --query "provisioningState"

# List private endpoints
az network private-endpoint list \
  --resource-group rg-lab-hubspoke \
  --output table
```

### Jumpbox Connectivity Testing

> **Note**: Jumpbox is **disabled by default** (`enable_jumpbox = false`). To test jumpbox connectivity, first enable it in `terraform.tfvars` and run `tofu apply`.

**1. Connect to jumpbox via DNAT:**
```bash
# Get SSH command from outputs (returns null if disabled)
tofu output jumpbox_ssh_via_firewall

# Connect (example, when enabled)
ssh -p 2222 azureuser@<firewall-public-ip>

# If you have custom SSH key location:
ssh -i ~/.ssh/azure_lab_key -p 2222 azureuser@<firewall-public-ip>
```

**2. Test connectivity from jumpbox:**
```bash
# Once connected to jumpbox, test various connections:

# Test internet connectivity
curl -I https://google.com

# Test DNS resolution (should use Azure DNS)
nslookup microsoft.com

# Test on-premises DNS (via DNS Private Resolver)
nslookup server.home.arpa

# Test connectivity to on-premises network (via VPN)
ping 192.168.1.1

# Test connectivity to spoke VMs (via VNet peering)
ping 10.20.1.10

# Test Azure CLI (if installed)
az account show

# Test private endpoint connectivity (ACR)
nslookup <registry-name>.azurecr.io  # Should resolve to private IP
```

**3. Security verification:**
```bash
# Verify jumpbox uses firewall for egress
# From jumpbox, check route table:
ip route

# Should show default route pointing to firewall IP (10.10.0.4)
```

### Test Connectivity

From an Azure VM in the spoke:
```bash
# Test internet via firewall
curl https://ifconfig.me

# Test on-premises connectivity
ping 192.168.1.1

# Test ACR private endpoint
nslookup acrlabunique12345.azurecr.io
# Should resolve to 10.20.3.x (private IP)

# Test Key Vault
nslookup kvlabunique12345.vault.azure.net
# Should resolve to 10.20.3.x (private IP)
```

##  Troubleshooting

### Deployment Mode Issues

#### FULL Mode Common Issues

**Problem**: VPN not connecting

**Solutions**:
```bash
# 1. Verify onprem_public_ip matches your WAN IP
tofu output vpn_gateway_public_ip

# 2. Verify vpn_shared_key matches on-prem device exactly
# Check terraform.tfvars and your on-prem VPN configuration

# 3. Check VPN connection status
az network vpn-connection show \
  --name lab-vpn-connection \
  --resource-group rg-lab-hub-network \
  --query connectionStatus
```

**Problem**: DNS not resolving on-premises domains

**Solutions**:
```bash
# 1. Verify onprem_dns_servers are reachable
# Test from jumpbox if deployed

# 2. Check forward_domain_name matches your internal domain
# In terraform.tfvars: forward_domain_name = "corp.local"

# 3. Verify DNS resolver status
az dns-resolver show \
  --name lab-dns-resolver \
  --resource-group rg-lab-hub-network \
  --query provisioningState
```

**Problem**: Cannot access private endpoints

**Solution**: Verify you're accessing from within Azure VNet or via VPN:
```bash
# Private endpoints are only accessible from:
# - Azure VMs in the VNet
# - On-premises via VPN connection
# - Cannot access from public internet
```

#### BASIC Mode Common Issues

**Problem**: Cannot access Key Vault or ACR

**Solution**: Configure Azure RBAC and authenticate:
```bash
# 1. Assign yourself Key Vault Administrator role
az role assignment create \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --role "Key Vault Administrator" \
  --scope $(az keyvault show --name <key_vault_name> --query id -o tsv)

# 2. For ACR, login via Azure CLI
az acr login --name <acr_name>

# 3. Verify public access is enabled
az keyvault show --name <key_vault_name> --query properties.publicNetworkAccess
# Should return: "Enabled"
```

**Problem**: Expected resources missing (VPN, DNS Resolver, Jumpbox)

**Solution**: This is expected in BASIC mode:
```bash
# BASIC mode excludes these resources by design
# To use them, re-run bootstrap.sh and select FULL mode (Option 1)

cd bootstrap
./bootstrap.sh

# Select: 1) Full mode
# Then reconfigure terraform.tfvars with VPN and DNS settings
```

**Problem**: Module not found errors (dns-private-resolver, vpn-s2s, compute-jumpbox)

**Solution**: These modules are not generated in BASIC mode:
```bash
# This is expected behavior
# If you need these modules, switch to FULL mode by:
# 1. Re-running bootstrap.sh and selecting FULL mode
# 2. Or manually creating the module directories and configurations
```

=======
### Jumpbox Connection Issues

**Problem**: Jumpbox-related outputs return `null`

**Solution**: The jumpbox is disabled by default. To enable it:
```bash
# In terraform.tfvars, set:
enable_jumpbox = true

# Then re-run:
tofu apply
```

**Problem**: Cannot SSH to jumpbox via firewall

**Solutions**:
```bash
# 1. Verify jumpbox is enabled
# In terraform.tfvars, ensure:
enable_jumpbox = true

# 2. Verify DNAT is enabled
enable_jumpbox_dnat = true

# 3. Verify firewall has public IP assigned
tofu output firewall_public_ip

# 4. Verify firewall provisioning state
az network firewall show \
  --name lab-azfw \
  --resource-group rg-lab-hub-network \
  --query "provisioningState"

# 5. Check DNAT rule exists
az network firewall nat-rule list \
  --resource-group rg-lab-hub-network \
  --firewall-name lab-azfw \
  --collection-name jumpbox-dnat

# 6. Verify your source IP is allowed (if configured)
# Check var.jumpbox_allowed_ssh_source in terraform.tfvars
```

**Problem**: VM creation fails with SKU capacity error

**Solution**: Change to a different VM size:
```bash
# In terraform.tfvars, try:
jumpbox_vm_size = "Standard_B2s"      # or
jumpbox_vm_size = "Standard_D2s_v3"   # or
jumpbox_vm_size = "Standard_B1ms"     # (smaller/cheaper)

# Then re-run:
tofu apply
```

**Problem**: SSH connection times out

**Troubleshooting steps**:
1. **Check firewall NSG** - Ensure port 2222 is allowed inbound
2. **Verify jumpbox is running** - Check VM status in Azure Portal
3. **Test firewall connectivity**: `nc -zv <firewall-ip> 2222`
4. **Check your SSH key** - Ensure you're using the correct private key
5. **Firewall logs** - Check Azure Firewall logs for denied connections

**Problem**: Can reach jumpbox but can't connect to other resources

```bash
# From jumpbox, verify routing:
ip route
# Should show default route to firewall (10.10.0.4)

# Test DNS resolution:
nslookup <acr-name>.azurecr.io
# Should resolve to private IP (10.20.3.x)

# Test VPN connectivity:
ping 192.168.1.1
# If fails, check VPN Gateway status
```

### VPN Connection Issues

## 📚 What Makes This Different?

### Remote State Management with Azure Storage

This infrastructure uses **Azure Storage Backend** for OpenTofu state:

```terraform
backend "azurerm" {
  resource_group_name  = "rg-tfstate"
  storage_account_name = "tfstate12345"  # Created by bootstrap.sh
  container_name       = "tfstate"
  key                  = "lab.tfstate"
  use_oidc             = true  # Passwordless authentication
}
```

**Why Remote State?**
- ✅ **State persistence** between CI/CD runs (no more "already exists" errors)
- ✅ **State locking** prevents concurrent modifications and corruption
- ✅ **Team collaboration** - multiple developers share the same state
- ✅ **Secure** - Encrypted at rest with Azure Storage encryption
- ✅ **OIDC authentication** - No storage keys in GitHub secrets

**Without remote state**, GitHub Actions would lose track of infrastructure after each run, causing deployment failures.

### Plan-Safe `for_each` Patterns

This code uses **map-based `for_each`** instead of list-based approaches:

```terraform
# ✅ Good: Map with stable keys
spoke_subnets = {
  apps = module.spoke1.apps_subnet_id
  apis = module.spoke1.apis_subnet_id
  data = module.spoke1.data_subnet_id
}

# ❌ Avoid: List causes plan instability
spoke_subnets = [
  module.spoke1.apps_subnet_id,
  module.spoke1.apis_subnet_id,
  module.spoke1.data_subnet_id
]
```

**Why?** Maps use stable keys, preventing unnecessary resource recreation when lists are reordered.

### Modular Design

Each infrastructure component is isolated in its own module:
- Easy to add/remove components
- Reusable across different environments
- Clear separation of concerns
- Simplified testing and maintenance

### Production-Ready Features

- Private endpoints (no public access to PaaS services)
- Firewall-based traffic inspection
- Hybrid DNS resolution
- Site-to-site VPN for on-premises connectivity
- GitHub Actions for CI/CD
- Comprehensive outputs for integration

## 🛠️ Customization

### Add More Spoke VNets

1. Copy the spoke module call in `envs/lab/main.tf`:
```terraform
module "spoke2" {
  source = "../../modules/network-spoke"
  
  name_prefix         = "${var.name_prefix}-2"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  
  vnet_cidr        = "10.30.0.0/16"
  apps_subnet_cidr = "10.30.1.0/24"
  apis_subnet_cidr = "10.30.2.0/24"
  data_subnet_cidr = "10.30.3.0/24"
}
```

2. Add peering to the hub in the peering module call:

```terraform
module "peering_routing" {
  source = "../../modules/peering-routing"
  
  hub_vnet_name           = module.hub.vnet_name
  hub_vnet_id             = module.hub.vnet_id
  hub_resource_group_name = azurerm_resource_group.hub_network.name
  
  spoke_vnets = {
    spoke1 = {
      vnet_name           = module.spoke1.vnet_name
      vnet_id             = module.spoke1.vnet_id
      resource_group_name = azurerm_resource_group.spoke_network.name
    }
    spoke2 = {
      vnet_name           = module.spoke2.vnet_name
      vnet_id             = module.spoke2.vnet_id
      resource_group_name = azurerm_resource_group.spoke_network.name
    }
  }
  
  # Spoke subnets to route through firewall
  spoke_subnets = {
    spoke1_apps = module.spoke1.apps_subnet_id
    spoke1_apis = module.spoke1.apis_subnet_id
    spoke1_data = module.spoke1.data_subnet_id
    spoke2_apps = module.spoke2.apps_subnet_id
    spoke2_apis = module.spoke2.apis_subnet_id
    spoke2_data = module.spoke2.data_subnet_id
  }
  
  firewall_private_ip = module.firewall.firewall_private_ip
  
  depends_on = [
    module.hub,
    module.spoke1,
    module.spoke2,
    module.firewall
  ]
}
```

### Change Azure Region

Update `location` in `terraform.tfvars`:
```terraform
location = "eastus"  # or any Azure region
```

### Adjust VPN Gateway SKU

For better performance or more features:
```terraform
vpn_gateway_sku = "VpnGw2"  # or VpnGw3, VpnGw4, VpnGw5
```
### Add Firewall Rules

Edit `modules/security-firewall/main.tf` to add rules:
```terraform
resource "azurerm_firewall_network_rule_collection" "example" {
  name                = "example-rules"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.resource_group_name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "allow-web"
    source_addresses      = ["10.20.0.0/16"]
    destination_ports     = ["80", "443"]
    destination_addresses = ["*"]
    protocols             = ["TCP"]
  }
}
```

## 📝 License

The code in this repo and blog post are provided as-is for educational and lab purposes.

## 💡 Use Cases

This infrastructure is ideal for:

- **Hybrid Cloud Labs**: Learn Azure networking with on-premises connectivity
- **Development Environments**: Isolated, secure environments for app development
- **POC/Testing**: Validate Azure services before production deployment
- **Learning Platform**: Hands-on experience with Azure networking concepts
- **Home Lab Extension**: Connect home lab to Azure securely

## 🔍 Troubleshooting

### VPN Not Connecting

1. Verify shared key matches on both sides
2. Check that on-premises public IP is correct
3. Ensure firewall allows UDP 500 and 4500
4. Review connection status in Azure Portal

### DNS Not Resolving

1. Verify DNS resolver is provisioned
2. Check forwarding rules configuration
3. Ensure VNet links are properly configured
4. Test with `nslookup` from Azure VM

### Private Endpoints Not Working

1. Verify private DNS zones are linked to VNets
2. Check private endpoint provisioning state
3. Ensure subnet has `private_endpoint_network_policies = "Disabled"`
4. Test with `nslookup` to verify private IP resolution

### Deployment Errors

```bash
# Enable detailed logging
export TF_LOG=DEBUG

# Re-run with verbose output
tofu apply
```

## 🗑️ Cleanup

To destroy all resources:

```bash
cd azure-lab-opentofu/envs/lab
tofu destroy
```

> ⚠️ **Warning**: This will permanently delete all resources. Confirm you have backups of any important data.

---

**Built by S.Buchanan ([www.buchatech.com](https://www.buchatech.com) )**

For questions or feedback, open an issue in this repository.






