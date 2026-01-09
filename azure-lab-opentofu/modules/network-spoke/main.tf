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
