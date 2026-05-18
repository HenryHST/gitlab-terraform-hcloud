terraform {
  # Terraform >= 1.14.4 (CI) and OpenTofu >= 1.9.0 (e.g. 1.12.x) share this HCL; see README “Terraform und OpenTofu”.
  required_version = ">= 1.9.0"

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
      version = "~> 18.11"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "<=3.0.2-rc07"
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

# Aliased provider for module.gitlab_api only (count = enable_gitlab_resources).
# v18+ with an empty token tries glab config-file auth and fails with "unable to locate config file" on every plan.
provider "gitlab" {
  alias    = "gitlab"
  token    = var.enable_gitlab_resources ? var.gitlab_api_token : "glpat-infrastructure-only-placeholder"
  base_url = var.gitlab_api_url
  # Skip API probe when GitLab is not provisioned yet or API resources are disabled.
  early_auth_check = var.enable_gitlab_resources
}
provider "proxmox" {
  alias               = "prod"
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token
  pm_tls_insecure     = var.pm_tls_insecure
}