location    = "centralus"
name_prefix = "sb-mvp-lab"

hub_resource_group_name        = "rg-sb-mvp-lab-hub-network"
spoke1_resource_group_name     = "rg-sb-mvp-lab-spoke1-network"
management_resource_group_name = "rg-sb-mvp-lab-management"

subscription_id = "5f6d5ced-5576-4c49-bb83-aefa1d3168db"

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

onprem_public_ip      = "67.4.128.139"
onprem_address_spaces = ["192.168.1.0/24"]
vpn_shared_key        = "REPLACE_ME"
vpn_gateway_sku       = "VpnGw1"

tenant_id = "3a5ab5f7-6efc-4a9f-8acd-f3946b2af582"

# MUST be globally unique + lowercase
acr_name       = "acrlabsteve12345"
key_vault_name = "kvlabsteve12345"

onprem_dns_servers  = ["192.168.1.1"]
forward_domain_name = "home.arpa."

# Jumpbox (optional)
enable_jumpbox         = false
jumpbox_private_ip     = "10.10.3.10"
jumpbox_vm_size        = "Standard_DS1_v2"
jumpbox_admin_username = "azureuser"
jumpbox_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSN324Zp5oxBoacpDz7AVDON5AtSYKysMSNMehQgexL jumpbox"

# Firewall DNAT -> jumpbox (only applies if enable_jumpbox=true)
enable_jumpbox_dnat        = true
jumpbox_inbound_port       = 2222
jumpbox_allowed_ssh_source = ["0.0.0.0/0"]
