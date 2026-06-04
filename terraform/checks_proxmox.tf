# Early, actionable errors for Proxmox + Hetzner GitLab mode combinations.

check "proxmox_tf_files_when_enabled" {
  assert {
    condition = (
      !var.enable_proxmox_resources ||
      (
        fileexists("${path.module}/proxmox.tf") &&
        fileexists("${path.module}/provider_proxmox.tf") &&
        fileexists("${path.module}/proxmox_variables.tf")
      )
    )
    error_message = <<-EOT
      enable_proxmox_resources is true but proxmox.tf, provider_proxmox.tf, and/or proxmox_variables.tf are missing.
      Run from terraform/:
        cp proxmox.tf.example proxmox.tf
        cp provider_proxmox.tf.example provider_proxmox.tf
        cp proxmox_variables.tf.example proxmox_variables.tf
        cp outputs_proxmox.tf.example outputs_proxmox.tf
        cp proxmox_data.tf.example proxmox_data.tf   # when gitlab_install_mode = "proxmox"
      Set proxmox_api_token, cipassword (min. 8 characters).
      Proxmox-only GitLab: gitlab_install_mode = "proxmox" (or legacy: "none" + proxmox_gitlab_docker_compose_enabled).
    EOT
  }
}

check "proxmox_tf_files_when_install_mode_proxmox" {
  assert {
    condition = (
      var.gitlab_install_mode != "proxmox" ||
      (
        fileexists("${path.module}/proxmox.tf") &&
        fileexists("${path.module}/provider_proxmox.tf") &&
        fileexists("${path.module}/proxmox_variables.tf") &&
        fileexists("${path.module}/proxmox_data.tf")
      )
    )
    error_message = <<-EOT
      gitlab_install_mode = "proxmox" requires proxmox.tf, provider_proxmox.tf, proxmox_variables.tf, and proxmox_data.tf.
      Run from terraform/:
        cp proxmox.tf.example proxmox.tf
        cp provider_proxmox.tf.example provider_proxmox.tf
        cp proxmox_variables.tf.example proxmox_variables.tf
        cp proxmox_data.tf.example proxmox_data.tf
        cp outputs_proxmox.tf.example outputs_proxmox.tf
    EOT
  }
}

check "proxmox_gitlab_not_parallel_hetzner_docker" {
  assert {
    condition = !(
      local.proxmox_gitlab_docker &&
      var.gitlab_install_mode == "docker_compose"
    )
    error_message = <<-EOT
      Proxmox GitLab and Hetzner docker_compose cannot run together.
      Proxmox-only: gitlab_install_mode = "proxmox" (recommended) or gitlab_install_mode = "none" with enable_proxmox_resources and proxmox_gitlab_docker_compose_enabled.
      Hetzner-only: enable_proxmox_resources = false (omit proxmox.tf / provider_proxmox.tf).
    EOT
  }
}
