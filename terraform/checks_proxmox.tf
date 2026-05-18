# Early, actionable errors for Proxmox + Hetzner GitLab mode combinations.

check "proxmox_tf_files_when_enabled" {
  assert {
    condition = (
      !var.enable_proxmox_resources ||
      (fileexists("${path.module}/proxmox.tf") && fileexists("${path.module}/provider_proxmox.tf"))
    )
    error_message = <<-EOT
      enable_proxmox_resources is true but proxmox.tf and/or provider_proxmox.tf are missing.
      Run from terraform/:
        cp proxmox.tf.example proxmox.tf
        cp provider_proxmox.tf.example provider_proxmox.tf
        cp outputs_proxmox.tf.example outputs_proxmox.tf
      Set proxmox_api_token, cipassword (min. 8 characters), and gitlab_install_mode = "none" for Proxmox-only GitLab.
    EOT
  }
}

check "proxmox_ci_password" {
  assert {
    condition     = !var.enable_proxmox_resources || length(var.cipassword) >= 8
    error_message = "enable_proxmox_resources is true: set cipassword (min. 8 characters) for Proxmox cloud-init."
  }
}

check "proxmox_gitlab_not_parallel_hetzner_docker" {
  assert {
    condition = !(
      local.proxmox_gitlab_docker &&
      var.gitlab_install_mode == "docker_compose"
    )
    error_message = <<-EOT
      Proxmox GitLab (proxmox_gitlab_docker_compose_enabled) and Hetzner docker_compose cannot run together.
      Proxmox-only: gitlab_install_mode = "none", enable_proxmox_resources = true, proxmox_gitlab_docker_compose_enabled = true.
      Hetzner-only: enable_proxmox_resources = false (omit proxmox.tf / provider_proxmox.tf).
    EOT
  }
}
