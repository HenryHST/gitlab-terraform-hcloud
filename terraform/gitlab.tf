module "gitlab_api" {
  count  = var.enable_gitlab_resources ? 1 : 0
  source = "./modules/gitlab-api"

  providers = {
    gitlab = gitlab.gitlab
  }

  domain = var.dns_domain

  create_renovate_hook = (
    var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_renovate_enabled
  )
  renovate_dns_label = var.gitlab_docker_renovate_dns_label
  renovate_webhook_token = (
    var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_renovate_enabled ?
    random_password.gitlab_renovate_webhook[0].result : ""
  )
}

resource "random_password" "gitlab_admin_password" {
  count   = var.enable_gitlab_resources ? 1 : 0
  length  = 24
  special = false
}

resource "gitlab_user" "gitlab_admin" {
  count    = var.enable_gitlab_resources ? 1 : 0
  provider = gitlab.gitlab

  name     = "GitLab Admin"
  username = "gadmin"
  email    = "gadmin@${var.dns_domain}"
  password = random_password.gitlab_admin_password[0].result
  note     = "GitLab Admin User"
  is_admin = true
}

resource "gitlab_group_membership" "gitlab_devops_admin" {
  count    = var.enable_gitlab_resources ? 1 : 0
  provider = gitlab.gitlab

  group_id     = module.gitlab_api[0].devops_group_id
  user_id      = gitlab_user.gitlab_admin[0].id
  access_level = "maintainer"
}

resource "gitlab_group" "gitlab_ci_components" {
  count    = var.enable_gitlab_resources ? 1 : 0
  provider = gitlab.gitlab

  path             = "ci_components"
  name             = "CI Components"
  description      = "CI Components Group"
  visibility_level = "private"
}

resource "gitlab_group" "gitlab_infrastructure" {
  count    = var.enable_gitlab_resources ? 1 : 0
  provider = gitlab.gitlab

  path             = "infrastructure"
  name             = "Infrastructure"
  description      = "Infrastructure Group"
  visibility_level = "private"
}
