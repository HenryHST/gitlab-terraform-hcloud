# GitLab CE ↔ PostgreSQL version pairing per https://docs.gitlab.com/install/requirements/

locals {
  gitlab_docker_images_apply = contains(["docker_compose", "proxmox"], var.gitlab_install_mode) || (
    var.enable_proxmox_resources && var.proxmox_gitlab_docker_compose_enabled
  )

  gitlab_ce_version_match = try(
    regex("^gitlab/gitlab-ce:([0-9]+)\\.([0-9]+)\\.([0-9]+)-ce\\.0$", var.gitlab_docker_gitlab_ce_image),
    [],
  )
  gitlab_ce_major = length(local.gitlab_ce_version_match) > 0 ? tonumber(local.gitlab_ce_version_match[0]) : null
  gitlab_ce_minor = length(local.gitlab_ce_version_match) > 0 ? tonumber(local.gitlab_ce_version_match[1]) : null

  # Suffix after major (and optional minor), e.g. -alpine from postgres:16-alpine.
  postgres_image_tag_suffix = try(
    regex("^postgres:[0-9]+(?:\\.[0-9]+)?(.+)$", var.gitlab_docker_postgres_image),
    "",
  )

  # GitLab 19.x requires PostgreSQL 17 only — auto-select postgres:17 (preserve tag suffix, default -alpine).
  gitlab_docker_postgres_image_effective = (
    local.gitlab_ce_major == 19 ? "postgres:17${local.postgres_image_tag_suffix != "" ? local.postgres_image_tag_suffix : "-alpine"}" :
    var.gitlab_docker_postgres_image
  )

  postgres_major_match = try(regex("^postgres:([0-9]+)", local.gitlab_docker_postgres_image_effective), [])
  postgres_major         = length(local.postgres_major_match) > 0 ? tonumber(local.postgres_major_match[0]) : null

  postgres_majors_allowed = (
    local.gitlab_ce_major == 19 ? [17] :
    local.gitlab_ce_major == 18 ? [16, 17] :
    local.gitlab_ce_major == 17 ? [14, 15, 16] :
    local.gitlab_ce_major == 16 ? [13, 14, 15] :
    []
  )

  postgres_version_compatible = (
    local.gitlab_ce_major == null ||
    local.postgres_major == null ||
    contains(local.postgres_majors_allowed, local.postgres_major)
  )
}

check "gitlab_docker_postgres_version" {
  assert {
    condition = (
      !local.gitlab_docker_images_apply ||
      local.postgres_version_compatible
    )
    error_message = <<-EOT
      PostgreSQL image major version is not supported for the pinned GitLab CE release.
      GitLab ${local.gitlab_ce_major}.${local.gitlab_ce_minor} (${var.gitlab_docker_gitlab_ce_image}) requires PostgreSQL major version(s): ${join(", ", [for m in local.postgres_majors_allowed : tostring(m)])}.
      Effective image: ${local.gitlab_docker_postgres_image_effective} (configured: ${var.gitlab_docker_postgres_image}).
      See https://docs.gitlab.com/install/requirements/ (GitLab 19.x: PostgreSQL 17 only; GitLab 18.x: 16.5–17.x).
    EOT
  }
}
