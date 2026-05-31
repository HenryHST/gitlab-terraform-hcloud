locals {
  gitlab_network = {
    ipconfig0            = var.gitlab_ipconfig0
    ip                   = try(regex("ip=([^,/]+)", var.gitlab_ipconfig0)[0], null)
    gateway              = try(regex("gw=([^,/]+)", var.gitlab_ipconfig0)[0], null)
    ip6                  = try(regex("ip6=([^,/]+)", var.gitlab_ipconfig0)[0], null)
    gateway6             = try(regex("gw6=([^,/]+)", var.gitlab_ipconfig0)[0], null)
    nameserver           = var.nameserver
    searchdomain         = var.searchdomain
    bridge               = var.network_bridge
    model                = var.network_model
    default_ipv4_address = proxmox_vm_qemu.gitlab.default_ipv4_address
    default_ipv6_address = proxmox_vm_qemu.gitlab.default_ipv6_address
  }

  runner_network = {
    ipconfig0            = var.runner_ipconfig0
    ip                   = try(regex("ip=([^,/]+)", var.runner_ipconfig0)[0], null)
    gateway              = try(regex("gw=([^,/]+)", var.runner_ipconfig0)[0], null)
    ip6                  = try(regex("ip6=([^,/]+)", var.runner_ipconfig0)[0], null)
    gateway6             = try(regex("gw6=([^,/]+)", var.runner_ipconfig0)[0], null)
    nameserver           = var.nameserver
    searchdomain         = var.searchdomain
    bridge               = var.network_bridge
    model                = var.network_model
    default_ipv4_address = var.enable_runner ? proxmox_vm_qemu.gitlab_runner[0].default_ipv4_address : null
    default_ipv6_address = var.enable_runner ? proxmox_vm_qemu.gitlab_runner[0].default_ipv6_address : null
  }
}

output "gitlab_vm_id" {
  description = "Proxmox VM ID of the GitLab VM"
  value       = proxmox_vm_qemu.gitlab.vmid
}

output "gitlab_vm_name" {
  description = "Proxmox VM name of the GitLab VM"
  value       = proxmox_vm_qemu.gitlab.name
}

output "gitlab_vm_status" {
  description = "Desired power state of the GitLab VM (Proxmox vm_state: running, stopped, or started)"
  value       = proxmox_vm_qemu.gitlab.vm_state
}

output "gitlab_vm_network" {
  description = "Network configuration and guest-agent reported addresses for the GitLab VM"
  value       = local.gitlab_network
}

output "gitlab_vm" {
  description = "GitLab VM summary: id, name, node, status, and network"
  value = {
    vm_id   = proxmox_vm_qemu.gitlab.vmid
    vm_name = proxmox_vm_qemu.gitlab.name
    node    = var.node
    status  = proxmox_vm_qemu.gitlab.vm_state
    network = local.gitlab_network
  }
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

output "runner_vm_status" {
  description = "Desired power state of the runner VM when enable_runner is true"
  value       = var.enable_runner ? proxmox_vm_qemu.gitlab_runner[0].vm_state : null
}

output "runner_vm_network" {
  description = "Network configuration and guest-agent reported addresses for the runner VM when enable_runner is true"
  value       = var.enable_runner ? local.runner_network : null
}

output "runner_vm" {
  description = "Runner VM summary when enable_runner is true; null otherwise"
  value = var.enable_runner ? {
    vm_id   = proxmox_vm_qemu.gitlab_runner[0].vmid
    vm_name = proxmox_vm_qemu.gitlab_runner[0].name
    node    = local.runner_node_effective
    status  = proxmox_vm_qemu.gitlab_runner[0].vm_state
    network = local.runner_network
  } : null
}
