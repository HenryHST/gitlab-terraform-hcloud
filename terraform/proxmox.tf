# Proxmox QEMU VMs (optional). GitLab stack cloud-init: templates/gitlab-docker-cloud-init.yaml.tpl via snippets.

locals {
  proxmox_runner_node_effective = var.proxmox_runner_node != "" ? var.proxmox_runner_node : var.proxmox_node
  proxmox_gitlab_cicustom       = local.proxmox_gitlab_docker ? "user=local:snippets/${var.proxmox_cloud_init_snippet_name}" : null
}

resource "proxmox_vm_qemu" "gitlab" {
  count    = var.enable_proxmox_resources ? 1 : 0
  provider = proxmox.prod

  name        = "gitlab"
  desc        = "GitLab CE + Traefik (Terraform cloud-init)"
  target_node = var.proxmox_node
  agent       = 1
  qemu_os     = var.vm_qemu_os
  bios        = var.vm_bios_host
  tags        = "docker,gitlab"

  define_connection_info = false

  clone      = var.proxmox_enable_clone ? var.clone_template : null
  full_clone = var.clone_full

  onboot           = true
  startup          = ""
  automatic_reboot = false

  cores   = var.vm_host_cores
  sockets = var.vm_host_sockets
  cpu     = "host"
  memory  = var.vm_host_memory

  scsihw   = var.scsihw
  bootdisk = var.bootdisk

  dynamic "disk" {
    for_each = var.proxmox_enable_clone ? [] : [1]
    content {
      storage = var.vm_default_storage
      type    = "scsi"
      size    = var.vm_default_disk_size
    }
  }

  network {
    bridge = var.vm_default_bridge
    model  = "virtio"
    tag    = -1
  }

  lifecycle {
    ignore_changes = [
      disk,
      sshkeys,
    ]
  }

  ipconfig0    = var.proxmox_gitlab_ipconfig0
  nameserver   = var.nameserver
  searchdomain = var.searchdomain
  ciuser       = var.ciuser
  cipassword   = var.cipassword
  sshkeys      = local.ssh_public_key_effective
  cicustom     = local.proxmox_gitlab_cicustom

  depends_on = [null_resource.proxmox_upload_cloud_init_snippet]
}

resource "proxmox_vm_qemu" "gitlab_runner" {
  count    = var.enable_proxmox_resources && var.proxmox_enable_runner ? 1 : 0
  provider = proxmox.prod

  name        = "gitlab-runner"
  desc        = "GitLab Runner (Proxmox; install runner manually or extend cloud-init)"
  target_node = local.proxmox_runner_node_effective
  agent       = 1
  qemu_os     = var.vm_qemu_os
  bios        = var.vm_bios_host
  tags        = "gitlab-runner"

  define_connection_info = false

  clone      = var.proxmox_enable_clone ? var.clone_template : null
  full_clone = var.clone_full

  onboot           = true
  startup          = ""
  automatic_reboot = false

  cores   = var.vm_default_cores
  sockets = var.vm_default_sockets
  cpu     = "host"
  memory  = var.vm_default_memory

  scsihw   = var.scsihw
  bootdisk = var.bootdisk

  dynamic "disk" {
    for_each = var.proxmox_enable_clone ? [] : [1]
    content {
      storage = var.vm_default_storage
      type    = "scsi"
      size    = var.vm_default_disk_size
    }
  }

  network {
    bridge = var.vm_default_bridge
    model  = "virtio"
    tag    = -1
  }

  lifecycle {
    ignore_changes = [
      disk,
      sshkeys,
    ]
  }

  ipconfig0    = var.proxmox_runner_ipconfig0
  nameserver   = var.nameserver
  searchdomain = var.searchdomain
  ciuser       = var.ciuser
  cipassword   = var.cipassword
  sshkeys      = local.ssh_public_key_effective
}
