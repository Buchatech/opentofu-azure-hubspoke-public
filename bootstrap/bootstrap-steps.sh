#!/usr/bin/env bash
################################################################################
# OpenTofu Azure Hub-Spoke Lab - Deployment Guide
################################################################################
#
# This file provides step-by-step instructions for deploying an Azure hub-spoke
# network architecture using OpenTofu with Azure Storage backend for remote state.
#
<<<<<<< HEAD
# DEPLOYMENT MODES:
# The bootstrap script supports two deployment modes:
#
# 1. FULL Mode (Option 1 - Default):
#    - Hub VNet with Azure Firewall, VPN Gateway, DNS Private Resolver
#    - Spoke VNet with peering and default route through firewall
#    - Private endpoints for Key Vault and Azure Container Registry
#    - Optional Jumpbox VM for secure management access
#    - GitHub Actions CI/CD pipeline with OIDC authentication
#    - Cost: ~$500-600/month
#
# 2. BASIC Mode (Option 2):
#    - Hub VNet with Azure Firewall (no VPN, no DNS Resolver)
#    - Spoke VNet with peering and default route through firewall
#    - Public access for Key Vault and Azure Container Registry
#    - No Jumpbox, no VPN Gateway, no DNS Private Resolver
#    - GitHub Actions CI/CD pipeline with OIDC authentication
#    - Cost: ~$250/month (50% savings)
#
# See DEPLOYMENT_MODES.md for detailed comparison and decision guide.
=======
# Architecture includes:
# - Hub VNet with Azure Firewall, VPN Gateway, DNS Private Resolver
# - Spoke VNet with peering and default route through firewall
# - Key Vault, Azure Container Registry, and optional Jumpbox
# - GitHub Actions CI/CD pipeline with OIDC authentication
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633
#
################################################################################

################################################################################
# STEP 1: Azure Authentication and Subscription Setup
################################################################################

echo "Step 1: Authenticating to Azure..."

# Login to Azure with Microsoft Graph permissions
az login --scope https://graph.microsoft.com/.default

# List available subscriptions
az account list -o table

# Set the subscription you want to use
az account set --subscription "<your-subscription-id-or-name>"

# Example:
# az account set --subscription "Visual Studio Enterprise Subscription"

# Verify the active subscription
az account show -o jsonc

# Save your subscription ID and tenant ID for later use
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "✅ Authenticated to subscription: $(az account show --query name -o tsv)"
echo "   Subscription ID: $SUBSCRIPTION_ID"
echo "   Tenant ID: $TENANT_ID"
echo ""

################################################################################
# STEP 2: Run Bootstrap Script to Create Infrastructure
################################################################################

echo "Step 2: Running bootstrap script..."

# The bootstrap.sh script will:
# 1. Prompt you to select deployment mode (FULL or BASIC)
# 2. Create Azure Storage Account for OpenTofu remote state (rg-tfstate)
# 3. Generate the OpenTofu repository structure with modules based on your choice
# 4. Configure backend in main.tf to use the storage account
# 5. Create GitHub Actions workflow files for CI/CD
# 6. Display storage account details and required GitHub secrets

cat << 'EOF'
DEPLOYMENT MODE SELECTION:

When you run the bootstrap script, you'll be prompted:

  Select deployment type:
    1) Full (Private endpoints, DNS Resolver, VPN, optional Jumpbox) [default]
    2) Basic (Public access, no DNS/VPN/Jumpbox)
  
  Enter choice [1-2]:

Choose based on your requirements:

FULL Mode (Option 1):
  - Best for: Production, hybrid cloud, complete network isolation
  - Includes: VPN Gateway, DNS Resolver, Private Endpoints, Optional Jumpbox
  - Cost: ~$500-600/month
  - Configuration complexity: High (15+ required variables)
  - Use when: You need on-premises connectivity and private networking

BASIC Mode (Option 2):
  - Best for: Development, testing, learning, cost optimization
  - Includes: Hub-Spoke network, Firewall, Public ACR/KeyVault
  - Cost: ~$250/month (50% savings)
  - Configuration complexity: Low (5 required variables)
  - Use when: You don't need VPN or private networking

See DEPLOYMENT_MODES.md for detailed comparison.

EOF
=======
# 1. Create Azure Storage Account for OpenTofu remote state (rg-tfstate)
# 2. Generate the OpenTofu repository structure with modules
# 3. Configure backend in main.tf to use the storage account
# 4. Create GitHub Actions workflow files for CI/CD
# 5. Display storage account details and required GitHub secrets

# Run the bootstrap script with your desired project name
bash ./bootstrap.sh azure-lab-opentofu

# Note: The storage account name is auto-generated (e.g., tfstate93306)
# Save this value - you'll need it for GitHub Actions configuration

echo "✅ Bootstrap script completed"
echo ""

################################################################################
# STEP 3: Configure Terraform Variables
################################################################################

echo "Step 3: Configuring terraform.tfvars..."

# Navigate to the lab environment
cd azure-lab-opentofu/envs/lab

# Edit terraform.tfvars with your specific values:
<<<<<<< HEAD
# Required variables depend on your deployment mode selection
=======
# Required variables to update:
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633

cat << 'EOF'
Variables to configure in terraform.tfvars:

<<<<<<< HEAD
═══════════════════════════════════════════════════════════════════════
FOR FULL MODE (if you selected Option 1):
═══════════════════════════════════════════════════════════════════════

REQUIRED Variables:

=======
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633
1. subscription_id     - Your Azure subscription ID
   Get with: az account show --query id -o tsv

2. tenant_id          - Your Azure AD tenant ID
   Get with: az account show --query tenantId -o tsv

<<<<<<< HEAD
3. onprem_public_ip   - Your on-premises public IP for VPN
   Example: "203.0.113.45"
=======
3. onprem_public_ip   - Your on-premises public IP for VPN (e.g., UniFi WAN IP)
   Format: "x.x.x.x/32"
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633

4. vpn_shared_key     - Pre-shared key for VPN (must match your on-prem device)
   Example: "YourSecureSharedKey123!"

<<<<<<< HEAD
5. onprem_dns_servers - List of on-premises DNS server IPs
   Example: ["192.168.1.10", "192.168.1.11"]

6. forward_domain_name - Your local domain for DNS forwarding
   Example: "corp.local"

7. acr_name           - Unique name for Azure Container Registry (lowercase alphanumeric)
   Example: "mybuchatechacr"

8. key_vault_name     - Unique name for Key Vault (alphanumeric and hyphens)
   Example: "my-buchatech-kv"

OPTIONAL Variables (for Jumpbox):

- enable_jumpbox             - Deploy jumpbox VM (default: false)
- jumpbox_ssh_public_key     - Your SSH public key if enabling jumpbox
- jumpbox_allowed_ssh_source - Source IP for SSH access (recommend your IP /32)
- jumpbox_vm_size            - VM size (default: Standard_DS1_v2)

═══════════════════════════════════════════════════════════════════════
FOR BASIC MODE (if you selected Option 2):
═══════════════════════════════════════════════════════════════════════

REQUIRED Variables (Much Simpler!):

1. subscription_id     - Your Azure subscription ID
   Get with: az account show --query id -o tsv

2. tenant_id          - Your Azure AD tenant ID
   Get with: az account show --query tenantId -o tsv

3. acr_name           - Unique name for Azure Container Registry (lowercase alphanumeric)
   Example: "mybuchatechacr"

4. key_vault_name     - Unique name for Key Vault (alphanumeric and hyphens)
   Example: "my-buchatech-kv"

OPTIONAL Variables:

- hub_vnet_cidr       - Hub VNet CIDR (default: ["10.0.0.0/16"])
- spoke_vnet_cidr     - Spoke VNet CIDR (default: ["10.1.0.0/16"])
- location            - Azure region (default: centralus)

Note: No VPN, DNS, or Jumpbox variables needed for BASIC mode!
=======
5. acr_name           - Unique name for Azure Container Registry (lowercase alphanumeric)
   Example: "mybuchatechacr"

6. key_vault_name     - Unique name for Key Vault (alphanumeric and hyphens)
   Example: "my-buchatech-kv"

Optional (defaults provided):
- location            - Azure region (default: centralus)
- environment         - Environment name (default: lab)
- enable_jumpbox      - Deploy jumpbox VM (default: false)
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633

EOF

# Open the file for editing
# Use your preferred editor: code, vim, nano, etc.
code terraform.tfvars

<<<<<<< HEAD
echo "✅ Configure the required variables for your deployment mode, then continue"
=======
echo "✅ Configure the required variables above, then continue"
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633
echo ""

################################################################################
# STEP 4: Deploy Infrastructure with OpenTofu
################################################################################

echo "Step 4: Deploying with OpenTofu..."

# Ensure you're in the lab environment directory
cd azure-lab-opentofu/envs/lab

# Format all OpenTofu files
tofu fmt -recursive

# Initialize OpenTofu (downloads providers and configures backend)
tofu init -upgrade

# Validate the configuration
tofu validate

# Preview the planned changes
tofu plan

# Review the plan output carefully, then apply when ready
tofu apply

echo "✅ Infrastructure deployed successfully"
echo ""

################################################################################
# STEP 5: State Migration (If Deploying Locally First)
################################################################################

echo "Step 5: Migrating state to Azure Storage..."

cat << 'EOF'
⚠️  IMPORTANT: State Migration

If you deployed locally first (tofu apply above), your state is currently local.
You need to migrate it to Azure Storage for GitHub Actions to work correctly.

Option A: Migrate Local State to Azure Storage
-----------------------------------------------
1. Check for local state files:
   ls -lh terraform.tfstate*

2. Migrate state to Azure backend:
   tofu init -migrate-state
   
   When prompted "Do you want to copy existing state to the new backend?"
   Type: yes

3. Verify state was uploaded:
   STORAGE_ACCOUNT="<your-storage-account-name>"  # From bootstrap output
   
   az storage blob list \
     --account-name $STORAGE_ACCOUNT \
     --container-name tfstate \
     --auth-mode key \
     --query "[].{name:name, size:properties.contentLength}" -o table
   
   Confirm lab.tfstate is ~50KB or larger (not empty!)

4. Cleanup local state files (optional):
   rm terraform.tfstate terraform.tfstate.backup

Option B: Deploy from GitHub Actions First (Cleaner!)
------------------------------------------------------
If you haven't deployed yet:
1. Skip local deployment (don't run tofu apply locally)
2. Set up GitHub Actions (Steps 6-7 below)
3. Push code and let GitHub Actions deploy
4. Then work locally by running: tofu init

This approach is cleaner and avoids state migration!

EOF

echo ""
################################################################################
<<<<<<< HEAD
# STEP 6: Configure Site-to-Site VPN (FULL Mode Only)
################################################################################

echo "Step 6: VPN Gateway Configuration (if using FULL mode)..."

cat << 'EOF'
⚠️  NOTE: This step only applies if you selected FULL mode deployment!
    BASIC mode does not include VPN Gateway.

=======
# STEP 6: Configure Site-to-Site VPN (Optional)
################################################################################

echo "Step 6: VPN Gateway Configuration..."

cat << 'EOF'
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633
VPN Gateway Information for On-Premises Configuration
======================================================

After deployment, you'll need these values to configure your on-premises 
VPN device (e.g., UniFi Dream Machine, pfSense, etc.):

1. Azure VPN Gateway Public IP
   Get with: tofu output vpn_gateway_public_ip
   Or from Azure Portal:
   - Navigate to: Virtual network gateways
   - Select: lab-vpngw
   - Click: Overview
   - Copy: Public IP address

2. Azure Virtual Network Address Spaces
   Hub VNet:   10.10.0.0/16
   Spoke VNet: 10.20.0.0/16

3. On-Premises Network
   Your local network (configured in terraform.tfvars)
   Example: 192.168.1.0/24

4. Shared Key
   The vpn_shared_key you configured in terraform.tfvars
   MUST match on both sides!

On-Premises Device Configuration Example (UniFi):
--------------------------------------------------
- Connection Type: Site-to-Site VPN
- Remote Gateway: <Azure VPN Gateway Public IP>
- Pre-shared Key: <Your vpn_shared_key>
- Local Network: 192.168.1.0/24 (your home network)
- Remote Networks: 10.10.0.0/16, 10.20.0.0/16 (Azure VNets)
- IKE Version: IKEv2
- Encryption: AES-256
- Authentication: SHA256

EOF

# Get the VPN Gateway public IP
cd azure-lab-opentofu/envs/lab
echo "Azure VPN Gateway Public IP:"
tofu output vpn_gateway_public_ip

echo ""

################################################################################
# STEP 7: GitHub Actions Setup (CI/CD Pipeline)
################################################################################

echo "Step 7: Setting up GitHub Actions with OIDC authentication..."

cat << 'EOF'
GitHub Actions Configuration
=============================

This setup uses OpenID Connect (OIDC) for secure, keyless authentication
from GitHub Actions to Azure. No client secrets needed!

EOF

# Set your values (replace with your actual values)
GITHUB_ORG="YourGitHubUsername"              # Example: "Buchatech"
GITHUB_REPO="your-repo-name"                 # Example: "opentofu-azure-hubspoke-priv"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
APP_NAME="github-actions-opentofu-lab"

echo "Creating service principal with federated credentials..."

# Create the Azure AD application
az ad app create --display-name $APP_NAME

# Get the Application (client) ID and Object ID
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

# Assign Contributor role to the service principal
az role assignment create \
  --assignee $CLIENT_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID

# Get the service principal object ID
SP_OBJECT_ID=$(az ad sp show --id $CLIENT_ID --query id -o tsv)

# Grant service principal access to the state storage account
# Replace STORAGE_ACCOUNT_NAME with the value from bootstrap.sh output
STORAGE_ACCOUNT_NAME="tfstate12345"  # ⚠️ REPLACE WITH YOUR ACTUAL VALUE
TFSTATE_RG="rg-tfstate"

az role assignment create \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$TFSTATE_RG/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME"

# Display the values needed for GitHub Secrets
cat << EOF

================================================================================
GitHub Secrets Configuration
================================================================================

Configure these secrets in your GitHub repository:
(Settings > Secrets and variables > Actions > New repository secret)

Required Secrets:
-----------------
AZURE_CLIENT_ID:           $CLIENT_ID
AZURE_TENANT_ID:           $TENANT_ID
AZURE_SUBSCRIPTION_ID:     $SUBSCRIPTION_ID
TFSTATE_STORAGE_ACCOUNT:   $STORAGE_ACCOUNT_NAME
TFSTATE_RESOURCE_GROUP:    $TFSTATE_RG
TFSTATE_CONTAINER:         tfstate

================================================================================

⚠️  IMPORTANT: 
1. Replace STORAGE_ACCOUNT_NAME above with the actual value from bootstrap output
2. Add all 6 secrets to your GitHub repository before triggering workflows
3. The workflow will run automatically on:
   - Pull requests (plan only)
   - Push to main branch (plan + apply)

================================================================================
EOF

echo ""

################################################################################
# STEP 8: Push to GitHub Repository
################################################################################

echo "Step 8: Pushing code to GitHub..."

cat << 'EOF'
Push Code to GitHub
===================

Two options depending on your situation:

Option A: New Repository
-------------------------
1. Create repository on GitHub (public or private)
2. Initialize and push:

   cd azure-lab-opentofu
   git init
   git add .
   git commit -m "Initial commit: Azure hub-spoke infrastructure with OpenTofu"
   git branch -M main
   git remote add origin https://github.com/YourUsername/your-repo-name.git
   git push -u origin main

Option B: Existing Repository (Feature Branch)
-----------------------------------------------
1. Create and checkout feature branch:

   git checkout -b feature/azure-infrastructure

2. Stage and commit changes:

   git add .
   git commit -m "Add Azure hub-spoke infrastructure with OpenTofu and GitHub Actions"

3. Push feature branch:

   git push -u origin feature/azure-infrastructure

4. Create Pull Request on GitHub (will trigger plan workflow)

5. Merge to main (will trigger apply workflow)

Using VS Code:
--------------
1. Open Source Control panel (Ctrl+Shift+G)
2. Stage changes (click + icon)
3. Enter commit message
4. Click ✓ Commit button
5. Click ⋯ menu > Push

EOF

# Example commands (customize for your repository):
cat << 'EXAMPLE'

Example Commands:
-----------------
cd "/c/Users/bucha/OneDrive/TechShareCloud/Technical-Stuff/Custom Solutions/Azure and Azure Stack/azure-lab-opentf"

# Stage all changes
git add .

# Commit with descriptive message
git commit -m "Add Azure hub-spoke infrastructure with remote state and CI/CD"

# Push to main branch
git push origin main

# Or push to feature branch
git push origin feature/your-feature-name

EXAMPLE

echo ""

################################################################################
# STEP 9: Verify GitHub Actions Workflow
################################################################################

echo "Step 9: Monitoring GitHub Actions..."

cat << 'EOF'
Verify Deployment
=================

1. Navigate to your GitHub repository
2. Click "Actions" tab
3. Watch the workflow run:
   - Pull requests: Plan only (shows proposed changes)
   - Push to main: Plan + Apply (deploys infrastructure)

4. Review workflow output:
   - Green checkmark = Success
   - Red X = Failed (check logs for details)

5. Common issues and solutions:
   - "Backend authentication failed"
     → Verify GitHub Secrets are configured correctly
     → Check service principal has Storage Blob Data Contributor role
   
   - "Resource already exists" errors
     → State file may be empty or not migrated properly
     → See Step 5 for state migration instructions
   
   - "VNet is not in succeeded state"
     → This should be resolved with depends_on blocks
     → If persists, re-run the workflow

6. Verify infrastructure in Azure Portal:
   - Resource Groups: rg-lab-network-hub, rg-lab-network-spoke, rg-lab-mgmt
   - Key resources: VNets, Firewall, VPN Gateway, Key Vault, ACR

EOF

echo ""

################################################################################
# Additional Tips and Troubleshooting
################################################################################

cat << 'EOF'
================================================================================
Additional Tips
================================================================================

Working with OpenTofu Locally:
-------------------------------
# Pull latest state from Azure Storage
tofu refresh

# Preview changes without applying
tofu plan

# Apply specific resource
tofu apply -target=module.security_firewall

<<<<<<< HEAD
# Destroy specific resource (example for FULL mode - jumpbox won't exist in BASIC mode)
=======
# Destroy specific resource
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633
tofu destroy -target=module.jumpbox

# View outputs
tofu output

# Show state
tofu show

Cleaning Up:
------------
# Destroy all infrastructure (be careful!)
cd azure-lab-opentofu/envs/lab
tofu destroy

# Remove state storage (after destroying infrastructure)
az group delete --name rg-tfstate --yes --no-wait

# Delete service principal
az ad app delete --id <CLIENT_ID>

<<<<<<< HEAD
Consider deallocating resources when not in use (FULL mode only):
=======
Consider deallocating resources when not in use:
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633
az vm deallocate --resource-group rg-lab-mgmt --name lab-jumpbox

Useful Azure CLI Commands:
---------------------------
# List all resources in a resource group
az resource list --resource-group rg-lab-network-hub -o table

<<<<<<< HEAD
# Get VPN connection status (FULL mode only)
=======
# Get VPN connection status
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633
az network vpn-connection show \
  --name lab-vpn-connection \
  --resource-group rg-lab-network-hub \
  --query connectionStatus -o tsv

<<<<<<< HEAD
# View firewall logs (both modes)
=======
# View firewall logs
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallApplicationRule'"

<<<<<<< HEAD
# Check DNS resolver status (FULL mode only)
=======
# Check DNS resolver status
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633
az dns-resolver show \
  --name lab-dns-resolver \
  --resource-group rg-lab-network-hub

Troubleshooting Resources:
---------------------------
- OpenTofu Documentation: https://opentofu.org/docs/
- Azure Provider: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- GitHub Actions: https://docs.github.com/en/actions
- Azure Networking: https://learn.microsoft.com/azure/networking/

<<<<<<< HEAD
Deployment Mode Differences Reference:
---------------------------------------------
FULL Mode Resources:
  ✅ Hub VNet with Firewall, VPN Gateway, DNS Resolver
  ✅ Spoke VNet with Private Endpoints
  ✅ Optional Jumpbox VM
  ✅ Private DNS Zones
  ✅ Site-to-Site VPN connectivity

BASIC Mode Resources:
  ✅ Hub VNet with Firewall (no VPN, no DNS Resolver)
  ✅ Spoke VNet with Public access
  ❌ No Jumpbox
  ❌ No Private Endpoints
  ❌ No VPN Gateway
  ❌ No DNS Private Resolver

For detailed comparison and decision guide:
See DEPLOYMENT_MODES.md in the repository root

=======
>>>>>>> 1afffe296311bb9602bbd4d188982b29e2020633
EOF
