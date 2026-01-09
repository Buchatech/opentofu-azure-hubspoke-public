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
