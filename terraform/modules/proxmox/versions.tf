terraform {
  required_providers {
    proxmox = {
      source                = "telmate/proxmox"
      version               = "<=3.0.2-rc07"
      configuration_aliases = [proxmox]
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
