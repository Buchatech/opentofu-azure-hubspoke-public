resource "azurerm_public_ip" "pip" {
  name                = "${var.name_prefix}-pip-azfw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "fw" {
  name                = "${var.name_prefix}-azfw"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku_name = "AZFW_VNet"
  sku_tier = "Standard"

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

resource "azurerm_firewall_nat_rule_collection" "jumpbox_dnat" {
  count               = var.enable_jumpbox_dnat ? 1 : 0
  name                = "${var.name_prefix}-nat-jumpbox"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.resource_group_name
  priority            = 100
  action              = "Dnat"

  rule {
    name                  = "dnat-ssh-jumpbox"
    protocols             = ["TCP"]
    source_addresses      = var.jumpbox_allowed_sources
    destination_addresses = [azurerm_public_ip.pip.ip_address]
    destination_ports     = [tostring(var.jumpbox_inbound_port)]
    translated_address    = var.jumpbox_private_ip
    translated_port       = "22"
  }
}

resource "azurerm_firewall_network_rule_collection" "jumpbox_allow" {
  count               = var.enable_jumpbox_dnat ? 1 : 0
  name                = "${var.name_prefix}-net-jumpbox"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.resource_group_name
  priority            = 110
  action              = "Allow"

  rule {
    name                  = "allow-ssh-to-jumpbox"
    protocols             = ["TCP"]
    source_addresses      = var.jumpbox_allowed_sources
    destination_addresses = [var.jumpbox_private_ip]
    destination_ports     = ["22"]
  }
}
