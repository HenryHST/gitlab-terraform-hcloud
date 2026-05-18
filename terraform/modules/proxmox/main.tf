# Proxmox QEMU VMs and optional GitLab docker_compose cloud-init snippet upload.

locals {
  runner_node_effective = var.runner_node != "" ? var.runner_node : var.node
  gitlab_cicustom       = var.gitlab_docker_enabled ? "user=local:snippets/${var.cloud_init_snippet_name}" : null
  upload_snippet        = var.gitlab_docker_enabled && var.gitlab_docker_user_data != ""
}

resource "local_sensitive_file" "gitlab_cloud_init" {
  count = local.upload_snippet ? 1 : 0

  content         = var.gitlab_docker_user_data
  filename        = "${path.module}/.generated/${var.cloud_init_snippet_name}"
  file_permission = "0600"
}

resource "null_resource" "upload_cloud_init_snippet" {
  count = local.upload_snippet ? 1 : 0

  triggers = {
    content_sha = sha256(var.gitlab_docker_user_data)
    node        = var.node
    storage     = var.snippet_storage
    filename    = var.cloud_init_snippet_name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      curl -sfS${var.tls_insecure ? " -k" : ""} -X POST \
        -H "Authorization: PVEAPIToken=${var.api_token_id}=${var.api_token}" \
        -F "content=@${local_sensitive_file.gitlab_cloud_init[0].filename}" \
        "${trimsuffix(var.api_url, "/")}/nodes/${var.node}/storage/${var.snippet_storage}/upload?content=snippets&filename=snippets%2F${var.cloud_init_snippet_name}"
    EOT
  }

  depends_on = [local_sensitive_file.gitlab_cloud_init]
}

resource "proxmox_vm_qemu" "gitlab" {
  provider = proxmox

  name        = var.gitlab_vm_name
  desc        = "GitLab CE + Traefik (Terraform cloud-init)"
  target_node = var.node
  agent       = 1
  qemu_os     = var.vm_qemu_os
  bios        = var.vm_bios
  tags        = "docker,gitlab"

  define_connection_info = false

  clone      = var.enable_clone ? var.clone_template : null
  full_clone = var.clone_full

  onboot           = true
  startup          = ""
  automatic_reboot = false

  cores   = var.gitlab_cores
  sockets = var.gitlab_sockets
  cpu     = "host"
  memory  = var.gitlab_memory

  scsihw   = var.scsihw
  bootdisk = var.bootdisk

  dynamic "disk" {
    for_each = var.enable_clone ? [] : [1]
    content {
      storage = var.disk_storage
      type    = "scsi"
      size    = var.disk_size
    }
  }

  network {
    bridge = var.network_bridge
    model  = "virtio"
    tag    = -1
  }

  lifecycle {
    ignore_changes = [
      disk,
      sshkeys,
    ]
  }

  ipconfig0    = var.gitlab_ipconfig0
  nameserver   = var.nameserver
  searchdomain = var.searchdomain
  ciuser       = var.ciuser
  cipassword   = var.cipassword
  sshkeys      = var.ssh_public_key
  cicustom     = local.gitlab_cicustom

  depends_on = [null_resource.upload_cloud_init_snippet]
}

resource "proxmox_vm_qemu" "gitlab_runner" {
  count    = var.enable_runner ? 1 : 0
  provider = proxmox

  name        = var.runner_vm_name
  desc        = "GitLab Runner (install runner manually or extend cloud-init)"
  target_node = local.runner_node_effective
  agent       = 1
  qemu_os     = var.vm_qemu_os
  bios        = var.vm_bios
  tags        = "gitlab-runner"

  define_connection_info = false

  clone      = var.enable_clone ? var.clone_template : null
  full_clone = var.clone_full

  onboot           = true
  startup          = ""
  automatic_reboot = false

  cores   = var.runner_cores
  sockets = var.runner_sockets
  cpu     = "host"
  memory  = var.runner_memory

  scsihw   = var.scsihw
  bootdisk = var.bootdisk

  dynamic "disk" {
    for_each = var.enable_clone ? [] : [1]
    content {
      storage = var.disk_storage
      type    = "scsi"
      size    = var.disk_size
    }
  }

  network {
    bridge = var.network_bridge
    model  = "virtio"
    tag    = -1
  }

  lifecycle {
    ignore_changes = [
      disk,
      sshkeys,
    ]
  }

  ipconfig0    = var.runner_ipconfig0
  nameserver   = var.nameserver
  searchdomain = var.searchdomain
  ciuser       = var.ciuser
  cipassword   = var.cipassword
  sshkeys      = var.ssh_public_key
}
