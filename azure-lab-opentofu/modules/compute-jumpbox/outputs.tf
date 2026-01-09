output "private_ip" {
  value = var.enabled ? var.private_ip : null
}
