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
  description = "Public SSH key for server access"
  sensitive   = true
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
