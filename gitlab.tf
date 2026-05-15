### GitLab provider resources (groups, projects) ###

resource "gitlab_group" "devops_group" {
  count = var.enable_gitlab_resources ? 1 : 0

  path = "devops"
  name = "DevOps"
}

resource "gitlab_project" "devops" {
  count = var.enable_gitlab_resources ? 1 : 0

  name             = "devops"
  description      = "DevOps Project"
  visibility_level = "public"
  namespace_id     = gitlab_group.devops_group[0].id
}

resource "gitlab_project" "terraform" {
  count = var.enable_gitlab_resources ? 1 : 0

  name             = "terraform"
  description      = "Terraform Project"
  visibility_level = "public"
}
resource "gitlab_user" "renovate-bot" {
  count    = var.enable_gitlab_resources ? 1 : 0
  name     = "Renovate Bot"
  username = "renovate-bot"
  email    = "renovate-bot@${var.domain_cicd_showcase_de}"
  #password = random_password.renovate-bot.result
}
resource "gitlab_group_membership" "renovate-bot" {
  count        = var.enable_gitlab_resources ? 1 : 0
  group_id     = gitlab_group.devops_group[0].id
  user_id      = gitlab_user.renovate-bot[0].id
  access_level = "maintainer"
}
resource "gitlab_project_hook" "renovate_bot" {
  count = (
    var.enable_gitlab_resources &&
    var.gitlab_install_mode == "docker_compose" &&
    var.gitlab_docker_renovate_enabled
  ) ? 1 : 0

  project = gitlab_project.terraform[0].id
  url     = "https://${var.gitlab_docker_renovate_dns_label}.${var.domain_cicd_showcase_de}/webhook"
  name    = "renovate"
  token   = random_password.gitlab_renovate_webhook[0].result
}