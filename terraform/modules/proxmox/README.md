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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | >= 3.0.0, <= 3.0.2-rc07 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_local"></a> [local](#provider\_local) | ~> 2.5 |
| <a name="provider_null"></a> [null](#provider\_null) | ~> 3.2 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | >= 3.0.0, <= 3.0.2-rc07 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_wait"></a> [additional\_wait](#input\_additional\_wait) | Extra wait after clone before configure | `number` | `5` | no |
| <a name="input_api_token"></a> [api\_token](#input\_api\_token) | Proxmox API token secret | `string` | n/a | yes |
| <a name="input_api_token_id"></a> [api\_token\_id](#input\_api\_token\_id) | Proxmox API token ID, e.g. terraform@pam!terraform | `string` | n/a | yes |
| <a name="input_api_url"></a> [api\_url](#input\_api\_url) | Proxmox API URL, e.g. https://pve.example:8006/api2/json | `string` | n/a | yes |
| <a name="input_bootdisk"></a> [bootdisk](#input\_bootdisk) | Boot disk device | `string` | `"scsi0"` | no |
| <a name="input_cipassword"></a> [cipassword](#input\_cipassword) | Cloud-init password for ciuser (min. 8 characters) | `string` | n/a | yes |
| <a name="input_ciuser"></a> [ciuser](#input\_ciuser) | Cloud-init default user | `string` | n/a | yes |
| <a name="input_clone_full"></a> [clone\_full](#input\_clone\_full) | Full clone vs linked clone | `bool` | `true` | no |
| <a name="input_clone_template"></a> [clone\_template](#input\_clone\_template) | Template VM name when enable\_clone is true | `string` | `"ubuntu-2404-cloudinit"` | no |
| <a name="input_clone_wait"></a> [clone\_wait](#input\_clone\_wait) | Seconds to wait after clone | `number` | `10` | no |
| <a name="input_cloud_init_snippet_name"></a> [cloud\_init\_snippet\_name](#input\_cloud\_init\_snippet\_name) | Filename under snippets/ on Proxmox storage | `string` | `"gitlab-docker-cloud-init.yaml"` | no |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | Disk size when not cloning (Proxmox format, e.g. 32G) | `string` | `"32G"` | no |
| <a name="input_disk_storage"></a> [disk\_storage](#input\_disk\_storage) | Storage for VM disks | `string` | `"local-lvm"` | no |
| <a name="input_enable_clone"></a> [enable\_clone](#input\_enable\_clone) | Clone from template instead of blank disk | `bool` | `true` | no |
| <a name="input_enable_runner"></a> [enable\_runner](#input\_enable\_runner) | Create a second VM for GitLab Runner | `bool` | `true` | no |
| <a name="input_gitlab_cores"></a> [gitlab\_cores](#input\_gitlab\_cores) | GitLab VM CPU cores | `number` | `4` | no |
| <a name="input_gitlab_docker_enabled"></a> [gitlab\_docker\_enabled](#input\_gitlab\_docker\_enabled) | Upload cloud-init snippet and set cicustom on GitLab VM | `bool` | `true` | no |
| <a name="input_gitlab_docker_user_data"></a> [gitlab\_docker\_user\_data](#input\_gitlab\_docker\_user\_data) | Rendered cloud-init YAML (#cloud-config) for GitLab docker\_compose stack | `string` | `""` | no |
| <a name="input_gitlab_ipconfig0"></a> [gitlab\_ipconfig0](#input\_gitlab\_ipconfig0) | Proxmox ipconfig0 for GitLab, e.g. ip=10.20.0.10/16,gw=10.20.0.1 | `string` | n/a | yes |
| <a name="input_gitlab_memory"></a> [gitlab\_memory](#input\_gitlab\_memory) | GitLab VM memory in MiB | `number` | `8192` | no |
| <a name="input_gitlab_sockets"></a> [gitlab\_sockets](#input\_gitlab\_sockets) | GitLab VM CPU sockets | `number` | `1` | no |
| <a name="input_gitlab_vm_name"></a> [gitlab\_vm\_name](#input\_gitlab\_vm\_name) | Proxmox VM name for GitLab | `string` | `"gitlab"` | no |
| <a name="input_gitlab_vmid"></a> [gitlab\_vmid](#input\_gitlab\_vmid) | Proxmox VM ID for GitLab; 0 = next free ID (telmate/proxmox provider) | `number` | `0` | no |
| <a name="input_nameserver"></a> [nameserver](#input\_nameserver) | DNS nameserver for cloud-init | `string` | n/a | yes |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Linux bridge for VM NIC | `string` | `"vmbr0"` | no |
| <a name="input_network_firewall"></a> [network\_firewall](#input\_network\_firewall) | Enable Proxmox firewall on NIC | `bool` | `false` | no |
| <a name="input_network_link_down"></a> [network\_link\_down](#input\_network\_link\_down) | Start NIC link down | `bool` | `false` | no |
| <a name="input_network_model"></a> [network\_model](#input\_network\_model) | NIC model (virtio recommended) | `string` | `"virtio"` | no |
| <a name="input_node"></a> [node](#input\_node) | Proxmox node name for the GitLab VM | `string` | n/a | yes |
| <a name="input_onboot"></a> [onboot](#input\_onboot) | Start VM on Proxmox host boot | `bool` | `true` | no |
| <a name="input_qemu_agent"></a> [qemu\_agent](#input\_qemu\_agent) | QEMU guest agent (0 or 1) | `number` | `1` | no |
| <a name="input_runner_cores"></a> [runner\_cores](#input\_runner\_cores) | Runner VM CPU cores | `number` | `2` | no |
| <a name="input_runner_ipconfig0"></a> [runner\_ipconfig0](#input\_runner\_ipconfig0) | Proxmox ipconfig0 for Runner VM | `string` | n/a | yes |
| <a name="input_runner_memory"></a> [runner\_memory](#input\_runner\_memory) | Runner VM memory in MiB | `number` | `4096` | no |
| <a name="input_runner_node"></a> [runner\_node](#input\_runner\_node) | Proxmox node for GitLab Runner VM; empty uses node | `string` | `""` | no |
| <a name="input_runner_sockets"></a> [runner\_sockets](#input\_runner\_sockets) | Runner VM CPU sockets | `number` | `1` | no |
| <a name="input_runner_vm_name"></a> [runner\_vm\_name](#input\_runner\_vm\_name) | Proxmox VM name for GitLab Runner | `string` | `"gitlab-runner"` | no |
| <a name="input_runner_vmid"></a> [runner\_vmid](#input\_runner\_vmid) | Proxmox VM ID for GitLab Runner; 0 = next free ID | `number` | `0` | no |
| <a name="input_scsihw"></a> [scsihw](#input\_scsihw) | SCSI controller type | `string` | `"virtio-scsi-pci"` | no |
| <a name="input_searchdomain"></a> [searchdomain](#input\_searchdomain) | DNS search domain for cloud-init | `string` | n/a | yes |
| <a name="input_skip_ipv6"></a> [skip\_ipv6](#input\_skip\_ipv6) | Skip IPv6 in provider | `bool` | `true` | no |
| <a name="input_snippet_storage"></a> [snippet\_storage](#input\_snippet\_storage) | Proxmox storage ID for snippet upload (must allow content snippets) | `string` | `"local"` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | SSH public key for cloud-init (ciuser) | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Proxmox VM tags (comma-separated) | `string` | `"docker,gitlab"` | no |
| <a name="input_tls_insecure"></a> [tls\_insecure](#input\_tls\_insecure) | Skip TLS verification for snippet upload curl | `bool` | `false` | no |
| <a name="input_vm_bios"></a> [vm\_bios](#input\_vm\_bios) | VM firmware: ovmf (UEFI) or seabios | `string` | `"ovmf"` | no |
| <a name="input_vm_qemu_os"></a> [vm\_qemu\_os](#input\_vm\_qemu\_os) | QEMU OS type (l26 for Linux 2.6+) | `string` | `"l26"` | no |
| <a name="input_vm_state"></a> [vm\_state](#input\_vm\_state) | VM state | `string` | `"stopped"` | no |
| <a name="input_vm_state_runner"></a> [vm\_state\_runner](#input\_vm\_state\_runner) | VM state for runner | `string` | `"stopped"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_gitlab_cloud_init_snippet"></a> [gitlab\_cloud\_init\_snippet](#output\_gitlab\_cloud\_init\_snippet) | cicustom user= path when gitlab\_docker\_enabled; null otherwise |
| <a name="output_gitlab_vm"></a> [gitlab\_vm](#output\_gitlab\_vm) | GitLab VM summary: id, name, node, status, and network |
| <a name="output_gitlab_vm_id"></a> [gitlab\_vm\_id](#output\_gitlab\_vm\_id) | Proxmox VM ID of the GitLab VM |
| <a name="output_gitlab_vm_name"></a> [gitlab\_vm\_name](#output\_gitlab\_vm\_name) | Proxmox VM name of the GitLab VM |
| <a name="output_gitlab_vm_network"></a> [gitlab\_vm\_network](#output\_gitlab\_vm\_network) | Network configuration and guest-agent reported addresses for the GitLab VM |
| <a name="output_gitlab_vm_status"></a> [gitlab\_vm\_status](#output\_gitlab\_vm\_status) | Desired power state of the GitLab VM (Proxmox vm\_state: running, stopped, or started) |
| <a name="output_runner_vm"></a> [runner\_vm](#output\_runner\_vm) | Runner VM summary when enable\_runner is true; null otherwise |
| <a name="output_runner_vm_id"></a> [runner\_vm\_id](#output\_runner\_vm\_id) | Proxmox VM ID of the runner VM when enable\_runner is true |
| <a name="output_runner_vm_name"></a> [runner\_vm\_name](#output\_runner\_vm\_name) | Proxmox VM name of the runner VM when enable\_runner is true |
| <a name="output_runner_vm_network"></a> [runner\_vm\_network](#output\_runner\_vm\_network) | Network configuration and guest-agent reported addresses for the runner VM when enable\_runner is true |
| <a name="output_runner_vm_status"></a> [runner\_vm\_status](#output\_runner\_vm\_status) | Desired power state of the runner VM when enable\_runner is true |
<!-- END_TF_DOCS -->
