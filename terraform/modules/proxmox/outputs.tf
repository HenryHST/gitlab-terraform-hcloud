output "gitlab_vm_id" {
  description = "Proxmox VM ID of the GitLab VM"
  value       = proxmox_vm_qemu.gitlab.vmid
}

output "gitlab_vm_name" {
  description = "Proxmox VM name of the GitLab VM"
  value       = proxmox_vm_qemu.gitlab.name
}

output "gitlab_cloud_init_snippet" {
  description = "cicustom user= path when gitlab_docker_enabled; null otherwise"
  value       = local.gitlab_cicustom
}

output "runner_vm_id" {
  description = "Proxmox VM ID of the runner VM when enable_runner is true"
  value       = var.enable_runner ? proxmox_vm_qemu.gitlab_runner[0].vmid : null
}

output "runner_vm_name" {
  description = "Proxmox VM name of the runner VM when enable_runner is true"
  value       = var.enable_runner ? proxmox_vm_qemu.gitlab_runner[0].name : null
}
