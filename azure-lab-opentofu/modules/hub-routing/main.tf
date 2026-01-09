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
