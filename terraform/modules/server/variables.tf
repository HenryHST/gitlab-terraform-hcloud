variable "server_name" {
  type        = string
  description = "Name of the server"
}

variable "server_type" {
  type        = string
  description = "Server type (e.g., cx23, cpx21)"
}

variable "location" {
  type        = string
  description = "Server location (e.g., nbg1, fsn1, hel1)"
}

variable "image" {
  type        = string
  default     = "ubuntu-24.04"
  description = "Operating system image"
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for server access (used only when create_ssh_key is true)"
  sensitive   = true
  default     = ""

  validation {
    condition     = !var.create_ssh_key || length(trimspace(var.ssh_public_key)) > 0
    error_message = "ssh_public_key is required when create_ssh_key is true."
  }
}

variable "create_ssh_key" {
  type        = bool
  default     = true
  description = "If true, create an hcloud_ssh_key from ssh_public_key. If false, attach existing keys via attach_ssh_key_ids (avoids Hetzner uniqueness_error when the same key is reused)."
}

variable "attach_ssh_key_ids" {
  type        = list(string)
  default     = []
  description = "Existing Hetzner SSH key IDs to attach to the server when create_ssh_key is false"

  validation {
    condition     = var.create_ssh_key || length(var.attach_ssh_key_ids) > 0
    error_message = "attach_ssh_key_ids must be non-empty when create_ssh_key is false."
  }
}

variable "ssh_key_name" {
  type        = string
  default     = ""
  description = "Name for the SSH key (auto-generated if empty)"
}

variable "firewall_ids" {
  type        = list(string)
  default     = []
  description = "List of firewall IDs to attach to the server"
}

variable "labels" {
  type = map(string)
  default = {
    managed_by = "terraform"
  }
  description = "Labels to apply to the server"
}

variable "user_data" {
  type        = string
  default     = ""
  description = "Cloud-Init user data script"
}

variable "enable_ipv4" {
  type        = bool
  default     = true
  description = "Enable IPv4 networking"
}

variable "enable_ipv6" {
  type        = bool
  default     = true
  description = "Enable IPv6 networking"
}

variable "enable_rdns" {
  type        = bool
  default     = false
  description = "Enable reverse DNS records"
}

variable "rdns_ipv4_domain" {
  type        = string
  default     = ""
  description = "Domain name for IPv4 reverse DNS (PTR record)"
}

variable "rdns_ipv6_domain" {
  type        = string
  default     = ""
  description = "Domain name for IPv6 reverse DNS (PTR record)"
}
