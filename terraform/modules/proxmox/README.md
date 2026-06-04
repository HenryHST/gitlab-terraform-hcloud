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

The root module enables this with `enable_proxmox_resources = true` (see [docs/proxmox.md](../../docs/proxmox.md)).

Module inputs are validated in `variables.tf` (format, bounds, Proxmox naming). Cross-field rules live in `checks.tf` (e.g. distinct VM names, IP configs, and VM IDs when the runner VM is enabled, non-empty cloud-init when `gitlab_docker_enabled` is true).

**VM IDs:** `gitlab_vmid` and `runner_vmid` default to `0` (provider assigns the next free cluster-wide ID). With `gitlab_install_mode = "proxmox"` in the root module, copy `proxmox_data.tf.example` → `proxmox_data.tf` for a plan-time API check that fixed IDs (> 0) are not already in use.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| proxmox | telmate/proxmox >= 3.0.0, <= 3.0.2-rc07 |
| null | ~> 3.2 |
| local | ~> 2.5 |

Copy `proxmox.tf.example` → `proxmox.tf`, `provider_proxmox.tf.example` → `provider_proxmox.tf`, `proxmox_variables.tf.example` → `proxmox_variables.tf`, `outputs_proxmox.tf.example` → `outputs_proxmox.tf`, and (for `gitlab_install_mode = "proxmox"`) `proxmox_data.tf.example` → `proxmox_data.tf`. Without those files and with `enable_proxmox_resources = false`, no Proxmox provider or API calls occur during `plan` (except the optional VM-ID external data when mode is `proxmox` and `proxmox_data.tf` is present).

## Outputs

| Output | Description |
|--------|-------------|
| `gitlab_vm_id` / `runner_vm_id` | Proxmox VM ID (`vmid`) |
| `gitlab_vm_status` / `runner_vm_status` | Desired power state (`vm_state`: `running`, `stopped`, `started`) |
| `gitlab_vm_network` / `runner_vm_network` | Cloud-init IP config, bridge/model, DNS, and guest-agent IPv4/IPv6 when available |
| `gitlab_vm` / `runner_vm` | Combined object with id, name, node, status, and network |
