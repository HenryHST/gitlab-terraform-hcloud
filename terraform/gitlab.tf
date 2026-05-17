module "gitlab_api" {
  count  = var.enable_gitlab_resources ? 1 : 0
  source = "./modules/gitlab-api"

  providers = {
    gitlab = gitlab.gitlab
  }

  domain = var.domain_cicd_showcase_de

  create_renovate_hook = (
    var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_renovate_enabled
  )
  renovate_dns_label = var.gitlab_docker_renovate_dns_label
  renovate_webhook_token = (
    var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_renovate_enabled ?
    random_password.gitlab_renovate_webhook[0].result : ""
  )
}
