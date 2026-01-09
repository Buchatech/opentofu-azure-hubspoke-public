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

output "vpn_gateway_public_ip" {
  value = module.vpn.vpn_gateway_public_ip
}

output "dns_inbound_endpoint_ip" {
  value = module.dns_resolver.inbound_endpoint_ip
}

output "acr_login_server" {
  value = module.services.acr_login_server
}

output "key_vault_uri" {
  value = module.services.key_vault_uri
}

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
