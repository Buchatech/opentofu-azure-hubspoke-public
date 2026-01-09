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
