terraform {
  required_version = ">=1.14.4"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.63"
    }
  }
}

# Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

# Same provider with alias for DNS resources (required by state)
provider "hcloud" {
  alias = "dns"
  token = var.hcloud_token
}