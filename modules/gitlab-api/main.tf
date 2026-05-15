resource "gitlab_group" "devops_group" {
  provider = gitlab
  path = "devops"
  name = "DevOps"
}

resource "gitlab_project" "devops" {
  provider = gitlab
  name             = "devops"
  description      = "DevOps Project"
  visibility_level = "public"
  namespace_id     = gitlab_group.devops_group.id
}

resource "gitlab_project" "terraform" {
  provider = gitlab
  name             = "terraform"
  description      = "Terraform Project"
  visibility_level = "public"
}

resource "gitlab_user" "renovate_bot" {
  provider = gitlab
  name     = "Renovate Bot"
  username = "renovate-bot"
  email    = "renovate-bot@${var.domain}"
}

resource "gitlab_group_membership" "renovate_bot" {
  provider = gitlab
  group_id     = gitlab_group.devops_group.id
  user_id      = gitlab_user.renovate_bot.id
  access_level = "maintainer"
}

resource "gitlab_project_hook" "renovate_bot" {
  provider = gitlab
  count    = var.create_renovate_hook ? 1 : 0

  project = gitlab_project.terraform.id
  url     = "https://${var.renovate_dns_label}.${var.domain}/webhook"
  name    = "renovate"
  token   = var.renovate_webhook_token
}
