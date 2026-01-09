resource "azurerm_private_dns_resolver" "resolver" {
  name                = "${var.name_prefix}-dnspr"
  location            = var.location
  resource_group_name = var.resource_group_name
  virtual_network_id  = var.hub_vnet_id
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "inbound" {
  name                    = "${var.name_prefix}-dnspr-in"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.resolver.id

  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = var.dns_inbound_subnet_id
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "outbound" {
  name                    = "${var.name_prefix}-dnspr-out"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.resolver.id
  subnet_id               = var.dns_outbound_subnet_id
}

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "ruleset" {
  name                = "${var.name_prefix}-dnspr-ruleset"
  location            = var.location
  resource_group_name = var.resource_group_name

  private_dns_resolver_outbound_endpoint_ids = [
    azurerm_private_dns_resolver_outbound_endpoint.outbound.id
  ]
}

resource "azurerm_private_dns_resolver_forwarding_rule" "forward" {
  name                      = "forward-onprem"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.ruleset.id
  domain_name               = var.forward_domain_name

  target_dns_servers {
    ip_address = var.onprem_dns_servers[0]
    port       = 53
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "links" {
  for_each = var.link_vnets

  name                      = "link-${each.key}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.ruleset.id
  virtual_network_id        = each.value
}
