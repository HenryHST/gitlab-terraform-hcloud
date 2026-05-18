# Proxmox module

Creates QEMU VMs on Proxmox VE for GitLab (and optionally GitLab Runner). When `gitlab_docker_enabled` is true, uploads rendered cloud-init to Proxmox snippets and attaches it via `cicustom`.

## Usage

```hcl
module "proxmox" {
  source = "./modules/proxmox"

  node                    = "pve01"
  api_url                 = var.proxmox_api_url
  api_token               = var.proxmox_api_token
  api_token_id            = var.proxmox_api_token_id
  gitlab_docker_user_data = local.gitlab_docker_user_data
  gitlab_ipconfig0        = "ip=10.20.0.10/16,gw=10.20.0.1"
  runner_ipconfig0        = "ip=10.20.0.11/16,gw=10.20.0.1"
  ssh_public_key          = local.ssh_public_key_effective
  ciuser                  = "admin"
  cipassword              = var.cipassword
  nameserver              = var.nameserver
  searchdomain            = var.searchdomain
}
```

The root module enables this with `enable_proxmox_resources = true` (see repository README, section GitLab auf Proxmox).

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| proxmox | telmate/proxmox <= 3.0.2-rc07 |
| null | ~> 3.2 |
| local | ~> 2.5 |

Copy `proxmox.tf.example` → `proxmox.tf`, `provider_proxmox.tf.example` → `provider_proxmox.tf`, and `outputs_proxmox.tf.example` → `outputs_proxmox.tf`. Without those files and with `enable_proxmox_resources = false`, no Proxmox provider or API calls occur during `plan`.
