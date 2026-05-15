terraform {
  required_version = ">=1.14.4"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.63"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "18.11.0"
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
provider "gitlab" {
  token    = var.gitlab_api_token
  base_url = var.gitlab_api_url
}