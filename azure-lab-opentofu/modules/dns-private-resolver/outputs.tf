output "inbound_endpoint_ip" {
  value = azurerm_private_dns_resolver_inbound_endpoint.inbound.ip_configurations[0].private_ip_address
}
