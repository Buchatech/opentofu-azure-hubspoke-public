output "vnet_id" { value = azurerm_virtual_network.hub.id }
output "vnet_name" { value = azurerm_virtual_network.hub.name }

output "firewall_subnet_id" { value = azurerm_subnet.firewall.id }
output "gateway_subnet_id" { value = azurerm_subnet.gateway.id }
output "management_subnet_id" { value = azurerm_subnet.management.id }
output "dns_inbound_subnet_id" { value = azurerm_subnet.dns_inbound.id }
output "dns_outbound_subnet_id" { value = azurerm_subnet.dns_outbound.id }
