variable "enabled" {
  type    = bool
  default = true
}

variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }

variable "subnet_id" { type = string }

variable "private_ip" {
  type        = string
  description = "Static private IP for the NIC"
}

variable "vm_size" { type = string }
variable "admin_username" { type = string }

variable "ssh_public_key" {
  type        = string
  description = "OpenSSH public key line (ssh-ed25519 ... or ssh-rsa ...)"
}
