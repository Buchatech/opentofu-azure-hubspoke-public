resource "azurerm_private_dns_zone" "kv_zone" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone" "acr_zone" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_links" {
  for_each = var.link_vnets

  name                  = "kv-link-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv_zone.name
  virtual_network_id    = each.value
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_links" {
  for_each = var.link_vnets

  name                  = "acr-link-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr_zone.name
  virtual_network_id    = each.value
}

resource "azurerm_container_registry" "acr" {
  name                          = var.acr_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
}

resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  public_network_access_enabled = false
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
}

resource "azurerm_private_endpoint" "acr_pe" {
  name                = "${var.name_prefix}-pe-acr"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.spoke_private_endpoints_subnet_id

  private_service_connection {
    name                           = "${var.name_prefix}-psc-acr"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr_zone.id]
  }
}

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "${var.name_prefix}-pe-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.spoke_private_endpoints_subnet_id

  private_service_connection {
    name                           = "${var.name_prefix}-psc-kv"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_zone.id]
  }
}
