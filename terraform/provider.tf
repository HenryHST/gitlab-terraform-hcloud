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
  # Reachability check only when explicitly enabled (GitLab must exist and DNS must resolve).
  early_auth_check = var.enable_gitlab_resources && var.gitlab_early_auth_check
}
