output "vnet_id" { value = azurerm_virtual_network.spoke.id }
output "vnet_name" { value = azurerm_virtual_network.spoke.name }

output "apps_subnet_id" { value = azurerm_subnet.apps.id }
output "apis_subnet_id" { value = azurerm_subnet.apis.id }
output "data_subnet_id" { value = azurerm_subnet.data.id }
